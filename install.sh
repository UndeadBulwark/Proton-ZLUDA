#!/usr/bin/env bash
#
# install.sh — convenience wrapper: find a Proton build, convert it to Proton-ZLUDA,
# and drop it straight into Steam's compatibilitytools.d.
#
# Usage: ./install.sh [proton_dir_or_tarball]
#   With no argument it tries the system proton-cachyos-slr, then GE-Proton.
#
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
TOOL_NAME="${TOOL_NAME:-ZludaProton}"
CD="${STEAM_COMPAT_TOOLS:-$HOME/.local/share/Steam/compatibilitytools.d}"

SRC="${1:-}"
if [ -z "$SRC" ]; then
  for c in /usr/share/steam/compatibilitytools.d/proton-cachyos-slr \
             "$CD/proton-cachyos-slr" \
             "$CD/GE-Proton11-7"; do
    [ -f "$c/proton" ] && { SRC="$c"; break; }
  done
fi
[ -n "$SRC" ] || { echo "usage: $0 <proton_dir_or_tarball>" >&2; exit 1; }

mkdir -p "$CD"
OUT="$CD/$TOOL_NAME"
echo "== installing Proton-ZLUDA as '$TOOL_NAME' from: $SRC"
"$here/convert.sh" "$SRC" "$OUT"
echo
echo "Installed: $OUT"
echo "Now: restart Steam, then per game set Properties > Compatibility > force '$TOOL_NAME',"
echo "and set PhysX to High in-game."
