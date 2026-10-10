# Third-party notices

Proton-ZLUDA is a thin set of scripts/patches. The prebuilt **tool release** bundles a patched
Proton plus third-party binaries. Nothing here is affiliated with Valve, AMD, or NVIDIA.

## ZLUDA
- Upstream: https://github.com/vosen/ZLUDA
- License: Apache-2.0 OR MIT
- Used: the Windows `nvcuda.dll` (32-bit shim + 64-bit), `zluda64_server.exe`, and the
  `amdhip64_7.dll` loader path (ZLUDA's 64-bit `nvcuda` loads `amdhip64_7.dll`).

## hipwine
- Upstream: https://github.com/opcod3/hipwine
- License: LGPL-2.1 (see upstream `LICENSE.md`)
- Used: built `amdhip64_7.dll` / `amdhip64_7.dll.so` (Windows HIP runtime bridging to host
  `libamdhip64.so`). The small naming patch we apply is in `assets/patches/`.

## Proton / proton-cachyos
- Upstream: https://github.com/ValveSoftware/Proton and https://github.com/CachyOS/proton-cachyos
- License: BSD-3-Clause plus component licenses (DXVK, VKD3D-Proton, Wine, FAudio, ...).
- The converter copies a Proton build **you already have** and patches a few files. We do not
  rehost Proton in the git repo; the prebuilt release is offered under Proton's own license terms,
  with `LICENSE`/component notices included in the tool directory.

## ROCm / HIP
- Upstream: https://github.com/ROCm
- The converter embeds a small closure of ROCm shared libraries (`libamdhip64`, `libhsa-runtime64`,
  `librocprofiler-register`) plus host dependencies, only so hipwine can load them from within the
  tool. These retain their upstream licenses.

## Not redistributed
- NVIDIA PhysX System Software / CUDA binaries — never included. Install the NVIDIA PhysX System
  Software into a game's prefix yourself if a title needs it (many, like Borderlands 2, install it
  automatically).
- Game files — never included.
