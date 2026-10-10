# Game notes

Proton-ZLUDA is game-agnostic: it just makes the game load ZLUDA's `nvcuda` and ensures ROCm is
reachable. What varies per game is **which PhysX generation** it uses and whether it gates GPU PhysX
behind an NVIDIA check.

## To enable it for a game

1. In Steam, set the game's **Compatibility → force `ZludaProton`**.
2. Set **PhysX to High** in-game (and/or in the config INI).
3. If the game ships its own ancient PhysX and won't engage GPU, install the **NVIDIA PhysX System
   Software** into the game's prefix (or let the game's installer do it — Borderlands 2 does).

## 32-bit PhysX — supported target

ZLUDA's 32-bit PhysX work targets PhysX 2.8.x / 3.x (32-bit). Author-tested titles:

- Borderlands 2 (AppID 49520) — verified here: `PhysX GPU Support: ENABLED`.
- Mirror's Edge, Alice: Madness Returns, Mafia II (Classic).

Other likely candidates (32-bit PhysX): Batman: Arkham Asylum / City / Origins.

Known quirks:

- Fluid simulations can be glitchy (ZLUDA limitation).
- Batman: Arkham Origins at PhysX High can produce geometry explosions.

## 64-bit GameWorks PhysX — experimental

PhysX 3.x-64 titles (e.g. Batman: Arkham Knight, Metro Redux, Killing Floor 2): ZLUDA's 64-bit CUDA
works, and the tool puts ZLUDA's 64-bit `nvcuda` in `system32`, so it *may* work — but ZLUDA's
PhysX-specific work is 32-bit oriented. Treat as experimental; report results.

## Games that gate GPU PhysX on NVIDIA

Some titles query NVAPI / the GPU vendor and hide the GPU PhysX option on AMD. Proton-ZLUDA already
handles this: it ships **ZLUDA's spoofing `nvapi`**, so the game sees an "NVIDIA" GPU and the setting
becomes selectable (verified with Borderlands 2 — "PhysX Effects: High" could then be changed, and the
game asks for a restart rather than crashing). If a title misbehaves with a spoofed NVAPI, rebuild the
tool with `NO_NVAPI_SPOOF=1`.

## Reporting a game

Please include: game + AppID, GPU, ROCm version, PhysX setting, the relevant lines from
`~/steam-<AppID>.log` (nvcuda/zluda64_server/amdhip loads) and the game's own `Launch.log`
(`PhysX GPU Support: ...`).
