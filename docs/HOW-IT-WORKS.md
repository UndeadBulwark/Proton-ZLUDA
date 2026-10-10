# How it works

## The problem

PhysX GPU acceleration is CUDA-only. On Windows, a PhysX game calls into `cudart*.dll` →
`nvcuda.dll` (the NVIDIA driver). In Wine, that driver doesn't exist on an AMD box, so PhysX falls
back to the CPU.

ZLUDA replaces `nvcuda.dll` with a translator that implements the CUDA driver API on top of AMD's
HIP/ROCm. ZLUDA v6/v7-preview ships **32-bit PhysX support** (PR #651): a 32-bit `nvcuda.dll` shim
that talks over a named pipe to a 64-bit `zluda64_server.exe`, because the LLVM compiler etc. is
64-bit only.

## What's missing on Linux

The 64-bit ZLUDA path expects a **Windows HIP runtime** (`amdhip64_7.dll`) to talk to the GPU.
Wine has no such thing — but ROCm on Linux does (`libamdhip64.so.7`). The solution is **hipwine**: a
tiny winelib DLL named `amdhip64_7.dll` whose Unix side loads `libamdhip64.so.7`.

So the full chain, all inside the game's Wine prefix, is:

```
Borderlands2.exe (32-bit)
   └─ loads  C:\windows\syswow64\nvcuda.dll            (ZLUDA 32-bit shim)
        └─ named-pipe IPC ─▶ zluda64_server.exe (64-bit)
              └─ loads  <tool>\zluda\nvcuda.dll        (ZLUDA 64-bit)
                   └─ LoadLibrary("amdhip64_7.dll")
                        └─ hipwine (winelib) ──▶ libamdhip64.so.7 ──▶ ROCm ──▶ gfx1201
```

No ZLUDA recompilation is required — only plumbing.

## Why the tool runs on the host (no container)

Steam normally runs Proton inside the *Steam Linux Runtime* container (pressure-vessel), which:

- does **not** mount `/opt/rocm`, so hipwine's `libamdhip64.so.7` can't be resolved, and
- may not pass `/dev/kfd` (needed by HIP), and
- has a different (older) glibc than your host ROCm libs were built against.

Removing `require_tool_appid` from the tool's `toolmanifest.vdf` makes Steam launch the tool on the
**host** instead. The Proton binaries run fine there (built against a newer/older glibc both work
forward), and now everything — ROCm libs, `/dev/kfd`, `/dev/dri` — is reachable.

## What the converter changes

`convert.sh` (idempotent) does:

1. **`proton` script** — appends `nvcuda=n` to `WINEDLLOVERRIDES` so Wine prefers the native ZLUDA
   `nvcuda` over Proton's disabled/builtin stub.
2. **`toolmanifest.vdf`** — removes `require_tool_appid` (host mode, see above).
3. **`default_pfx/.../nvcuda.dll`** — replaces the 64-bit (system32) and 32-bit (syswow64) stubs with
   ZLUDA's DLLs; sets the registry override `nvcuda = native`.
4. **hipwine** — installs `amdhip64_7.dll` + `amdhip64_7.dll.so` into `files/lib/wine/...` and sets the
   shim's RPATH to the embedded `zluda-libs` (`$ORIGIN/../../../../zluda-libs`), so it's self-contained
   and location-independent.
5. **`zluda/`** — embeds ZLUDA's Windows build inside the tool (the 64-bit server + DLLs).
6. **`user_settings.py`** — sets `ZLUDA64_PATH` (Windows path to the embedded `zluda/`) so the 32-bit
   shim can find `zluda64_server.exe`, plus `PROTON_LOG=1`.
7. **`compatibilitytool.vdf`** — sets the tool's internal/display name.

## Verified result

CachyOS, RX 9070 XT (gfx1201), ROCm 7.2.4, Proton-CachyOS 11.0:

- game loads `system32\nvcuda.dll` (shim), `zluda64_server.exe`, `amdhip64_7.dll` at startup,
- `zluda64_server.exe` stays resident, no CUDA/HIP errors,
- Borderlands 2 `Launch.log`: `PhysX GPU Support: ENABLED`,
- game is in-game and playable (`rocm-smi`: ~80–100% GPU).
