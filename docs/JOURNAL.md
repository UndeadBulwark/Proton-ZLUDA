# Borderlands 2 GPU PhysX via ZLUDA on AMD (CachyOS) — Journal

## Environment (Phase 0)
- OS: CachyOS (Arch-based, rolling), kernel 7.2.9-1-cachyos, KDE/Wayland (XWayland :0).
- GPU: AMD Radeon RX 9070 XT, Navi 48 (RDNA4), gfx1201.
- ROCm: **7.2.4 installed** (`rocm-hip-sdk`, `hsa-rocr`, `rocminfo`). `rocminfo` sees gfx1201 (RX 9070).
- Vulkan: present (Mesa/RADV). `vulkaninfo` OK.
- Steam: native, running (Steam Deck UI). Proton: 7.0, 9.0, Experimental, GE-Proton11-7, and system `proton-cachyos-slr` (CachyOS package, Proton 11.0, `/usr/share/steam/compatibilitytools.d/`).
- Build tools: `meson`, `ninja`, `mingw-w64-gcc` (x86_64 + i686) installed; system Wine 11.19.
- BL2 (49520) compat tool was `proton-cachyos-slr`. PhysX System Software is already installed inside the prefix by BL2's installscript (`C:\Program Files (x86)\NVIDIA Corporation\PhysX\`).

## Key finding vs the original plan
The pasted plan assumed ZLUDA 32-bit PhysX needs a new Wine↔native transport (native ROCm server). **Disproved.**
- ZLUDA **v7-preview.15** already ships 32-bit PhysX (PR #651 merged; docs `physx32.html`).
- Built **`hipwine`** (`~/Games/hipwine`, patched to emit `amdhip64_7.dll` + `.so`): a Windows HIP DLL bridging to Linux `libamdhip64.so.7`.
- PROVEN under plain Wine 11.19: 32-bit shim → `zluda64_server.exe` (IPC works) → 64-bit `nvcuda` → `amdhip64_7` → ROCm enumerates `AMD Radeon RX 9070 [ZLUDA]`, CUDA 13.0. So no transport rewrite is needed.

## Real blockers found
1. BL2 requires the Steam client → must launch via Steam.
2. Proton forces `nvcuda=disabled` (default_pfx registry) so ZLUDA never loads normally.
3. Steam runtime container does **not** mount `/opt/rocm` → hipwine `.so` failed to dlopen.

## Artifacts
- `~/Games/zluda-setup/zluda/` — ZLUDA v7-preview.15 Windows build.
- `~/Games/zluda-setup/amdhip-hipwine/lib/wine/` — built hipwine shim.
- `~/Games/zluda-setup/rocm-libs/` — bundled ROCm lib closure (34 MB) for use inside the container.
- `~/bl2-zluda/bundle-rocm.sh` — rebuilds the closure.
- Custom Steam tool: `~/.local/share/Steam/compatibilitytools.d/ZludaProton/` = copy of `proton-cachyos-slr` with:
  - `default_pfx/.../system32/nvcuda.dll` → ZLUDA 64-bit; `syswow64/nvcuda.dll` → ZLUDA 32-bit.
  - hipwine `amdhip64_7.dll`/`.so` installed into `files/lib/wine/{x86_64-windows,x86_64-unix}`; `.so` RPATH → `rocm-libs`.
  - `proton` script patched to append `nvcuda=n` to `WINEDLLOVERRIDES`.
  - `user_settings.py` sets `ZLUDA64_PATH` (+ PROTON_LOG).

## Progress log
- Backup of real prefix at `~/bl2-zluda/prefix-baseline`.
- Selected `ZludaProton` for 49520 (config.vdf CompatToolMapping; Steam restarted).
- Launch via Steam: **BL2 runs, Steam API OK** (no "Steam must be running"): our tool inherits Proton's `lsteamclient`.
- Log (`/tmp/opencode/steam-49520.log`) showed PhysX loading and then:
  - `Loaded C:\windows\system32\nvcuda.dll: native` (32-bit shim via SysWOW64) ✔
  - `Loaded Z:\...\zluda\nvcuda.dll: native` (64-bit server) ✔
  - `Loaded Z:\...\zluda\zluda64_server.exe` ✔
  - `err:module:open_builtin_so_file failed to load .so lib ".../amdhip64_7.dll.so"` → server crash `0xc06d007e`.
  - Cause: `/opt/rocm` not mounted in the Steam runtime.
  - Fix applied: bundle ROCm closure into `rocm-libs`, set shim RPATH to it.
- Game logged `PhysX GPU Support: DISABLED` at startup (nvapi reports no NVIDIA device) — to revisit once HIP loads.

## Next
- Relaunch; confirm hipwine `.so` loads and HIP initialises (`/dev/kfd` availability inside container is the next unknown).

## RESULT — GPU PhysX ENABLED (milestone)
- Selected `ZludaProton` for 49520; Steam API works (Proton `lsteamclient`).
- **Removed `require_tool_appid`** from the tool manifest so Steam runs it on the HOST (no steamrt container):
  host glibc + `/opt/rocm` + `/dev/kfd` reachable → hipwine `.so` loads.
- Set `PhysXLevel=2` in `WillowEngine.ini`; Launch.log now shows:
  - `[0000.57] Log: PhysX GPU Support: ENABLED`
- Startup load chain (verified in `/tmp/opencode/steam-49520.log`):
  - `C:\windows\system32\nvcuda.dll` (32-bit ZLUDA shim via SysWOW64)
  - `Z:\...\zluda\zluda64_server.exe` and `Z:\...\zluda\nvcuda.dll` (64-bit server)
  - `C:\windows\system32\amdhip64_7.dll` (hipwine winelib → `libamdhip64.so.7` → ROCm/gfx1201)
- `zluda64_server.exe` stays resident (IPC pipe names present). No CUDA/HIP errors.
- Game reached in-game (screenshot) and is playable; `rocm-smi` GPU% ~80-100%, SCLK 2070 MHz, 131 W.

## Still to prove (Phase 5 evidence)
- GPU-only PhysX effects actually executing (APEX/PhysX GPU kernels) — needs a PhysX-Heavy scene + ZLUDA trace.
- CPU vs GPU FPS comparison on the same route.

## Reproduce
1. Tool at `~/.local/share/Steam/compatibilitytools.d/ZludaProton/` (copy of proton-cachyos-slr, patched as above).
2. `config.vdf` CompatToolMapping `49520` → `ZludaProton`.
3. `PhysXLevel=2` in `WillowEngine.ini`.
