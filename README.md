# Proton-ZLUDA

Run **NVIDIA CUDA / GPU-PhysX Windows games on AMD Radeon GPUs under Steam on Linux**, using
[ZLUDA](https://github.com/vosen/ZLUDA) on top of ROCm.

Proton-ZLUDA is a drop-in Steam compatibility tool (a patched Proton) that:

- delivers ZLUDA's 32-bit/64-bit `nvcuda` to the game so CUDA/PhysX calls run on your AMD GPU,
- bridges Windows HIP to the host ROCm runtime with a small **hipwine** shim,
- runs on the **host** (not Steam's container) so ROCm and `/dev/kfd` are reachable.

It was developed and verified with **Borderlands 2** (AppID 49520, 32-bit PhysX) on
**CachyOS + Radeon RX 9070 XT (gfx1201)**: `PhysX GPU Support: ENABLED`, the in-game
**"PhysX Effects: High"** setting is selectable (thanks to the bundled nvapi spoof), and the game runs
at playable frame rates (no single-digit drop) — i.e. the GPU is doing the PhysX work.

> Status: **experimental**. ZLUDA's 32-bit PhysX support is young; expect per-game quirks.

---

## Quick start (prebuilt, drag & drop)

1. Download the latest **tool** release (`Proton-ZLUDA-<protonver>.tar.zst`) from the **Releases** page.
2. Extract it into Steam's compatibility tools folder:

   ```sh
   tar --zstd -xf Proton-ZLUDA-*.tar.zst -C ~/.local/share/Steam/compatibilitytools.d/
   ```

3. Restart Steam.
4. Per game: **Properties → Compatibility → Force the use of a specific Steam Play compatibility tool →
   `ZludaProton`**.
5. In-game, set **PhysX to High** (and enable it in the game's config if needed).

## Build it yourself / convert a new Proton version

The **converter** (`convert.sh`) turns *any* `proton-cachyos-slr` or GE-Proton build into Proton-ZLUDA,
so new Proton releases are one command:

```sh
./convert.sh /path/to/proton-cachyos-slr                 # -> ./Proton-ZLUDA-<version>/
./convert.sh ~/Downloads/proton-cachyos-slr-*.tar.gz     # works from a tarball too
```

Or install straight into Steam:

```sh
./install.sh                 # auto-detects system proton-cachyos-slr / GE-Proton
./install.sh <proton_dir>    # or point it at a specific build
```

`convert.sh` will download ZLUDA, build `hipwine`, and bundle the ROCm libs automatically if they
aren't already present (see *Requirements*).

## Requirements

- AMD Radeon GPU supported by **ROCm** (RX 5000 series or newer; `gfx1201`/RX 9070 tested). Install ROCm:
  `sudo pacman -S rocm-hip-sdk` (Arch/CachyOS) or your distro's ROCm.
- **Wine/Proton** to convert: `proton-cachyos-slr` (CachyOS) or GE-Proton.
- Build tools (only if the converter has to build the shim): `meson`, `ninja`, `winegcc` (Wine ≥ 10),
  `mingw-w64` — e.g. `sudo pacman -S meson ninja mingw-w64-gcc`.
- A Steam game with **PhysX** (32-bit titles work best).

## Per-game notes

- **32-bit PhysX (PhysX 2.8.x / 3.x-32)** — the supported target. e.g. Borderlands 2, Mirror's Edge,
  Alice: Madness Returns, Mafia II (Classic), Batman: Arkham Asylum/City/Origins.
- **64-bit GameWorks PhysX** — ZLUDA's 64-bit CUDA works, but 64-bit PhysX GPU is not the focus and
  may be partial. Try it, expect rough edges.
- Games that **gate the GPU PhysX option on an NVIDIA check** are handled: the tool ships **ZLUDA's
  spoofing `nvapi`** so the game sees an "NVIDIA" GPU and unlocks the setting (e.g. Borderlands 2's
  "PhysX Effects: High" becomes selectable). Disable with `NO_NVAPI_SPOOF=1` in `convert.sh` if a title
  misbehaves with a spoofed NVAPI.
- Known ZLUDA quirks: fluid sims can glitch; Batman: Arkham Origins at High can explode geometry.

See `docs/GAMES.md` for details.

## Troubleshooting

Enable logging (`PROTON_LOG=1` is already set in the generated `user_settings.py`) and read
`~/steam-<AppID>.log`. Key success lines:

```
Loaded ...system32\nvcuda.dll            # 32-bit ZLUDA shim
Loaded ...zluda\zluda64_server.exe       # 64-bit ZLUDA server
Loaded ...amdhip64_7.dll                 # hipwine -> libamdhip64 -> ROCm
```

And in the game's `Launch.log`: **`PhysX GPU Support: ENABLED`**.

If you see `failed to load .so lib .../amdhip64_7.dll.so`, the ROCm libs weren't found — re-run the
converter so `zluda-libs` is embedded (the shim's RPATH points at it).

## How it works

See `docs/HOW-IT-WORKS.md`. In short:

```
game (32-bit) ── loads ──> nvcuda.dll (ZLUDA 32-bit shim, SysWOW64)
                               │ IPC (named pipe)
                               ▼
                         zluda64_server.exe (64-bit) ── loads ──> nvcuda.dll (ZLUDA 64-bit)
                               │ LoadLibrary
                               ▼
                         amdhip64_7.dll (hipwine, winelib)  ──>  libamdhip64.so.7  ──>  ROCm (gfx1201)
```

No ZLUDA recompilation is needed: current ZLUDA already ships 32-bit PhysX support.

## Credits

- [ZLUDA](https://github.com/vosen/ZLUDA) by Andrzej Janik (vosen) — Apache-2.0 / MIT.
- [hipwine](https://github.com/opcod3/hipwine) by opcod3 — Windows HIP bridge (LGPL-2.1).
- Proton / [proton-cachyos](https://github.com/CachyOS/proton-cachyos) — BSD-3-Clause + component licenses.
- AMD ROCm, DXVK and friends — see `THIRD-PARTY-NOTICES.md`.

## AI disclosure

This project — the converter, scripts, and the reverse-engineering that produced them — was built with
**AI assistance** (an AI coding agent), and **human-tested** on CachyOS with a Radeon RX 9070 XT and
Borderlands 2. Review the scripts before running them.

## License

MIT — see `LICENSE`. Third-party components retain their own licenses (`THIRD-PARTY-NOTICES.md`).
