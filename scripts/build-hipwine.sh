#!/usr/bin/env bash
#
# build-hipwine.sh — clone opcod3/hipwine, apply the Proton-ZLUDA naming patch, build it.
# Produces: <outdir>/lib/wine/{x86_64-windows/amdhip64_7.dll, x86_64-unix/amdhip64_7.dll.so}
#
# Usage: build-hipwine.sh [outdir]   (default: $XDG_CACHE_HOME/proton-zluda/hipwine)
#
set -euo pipefail
here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
patch="$here/../assets/patches/hipwine-amdhip64_7.patch"
out="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/proton-zluda/hipwine}"

for t in git meson ninja winegcc; do command -v "$t" >/dev/null || { echo "missing build tool: $t" >&2; exit 1; }; done
[ -d /opt/rocm ] || { echo "ROCm not found at /opt/rocm (needed for HIP headers/libs)" >&2; exit 1; }

mkdir -p "$out"; src="$out/src"
if [ ! -d "$src/.git" ]; then
  git clone --depth 1 https://github.com/opcod3/hipwine "$src"
fi
cd "$src"
git checkout -- . 2>/dev/null || true
git apply --whitespace=nowarn "$patch" 2>/dev/null || patch -p1 < "$patch"

build="${out}/build-$$"; mkdir -p "$build"
./package-release.sh hipwine "$build" --fakedll
# package-release.sh creates <build>/amdhip-hipwine/lib/wine
rm -rf "$out/lib"; cp -a "$build/amdhip-hipwine/lib" "$out/lib"
rm -rf "$build"
echo "hipwine ready: $out/lib/wine"
