#!/usr/bin/env bash
#
# bundle-rocm.sh — collect the shared-library closure needed to load hipwine's
# amdhip64_7.dll.so (libamdhip64 + HSA runtime + their /opt/rocm and host deps)
# into one directory, so it can be embedded in the Proton-ZLUDA tool and loaded
# inside Steam's runtime environment.
#
# Usage: bundle-rocm.sh [outdir]   (default: $XDG_CACHE_HOME/proton-zluda/rocm-libs)
#
set -euo pipefail
OUT="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/proton-zluda/rocm-libs}"
HIP="$(ls /opt/rocm/lib/libamdhip64.so.7 2>/dev/null || true)"
[ -n "$HIP" ] || { echo "ROCm libamdhip64.so.7 not found under /opt/rocm/lib" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"
declare -A seen
queue=("$HIP")
while [ ${#queue[@]} -gt 0 ]; do
  f="${queue[0]}"; queue=("${queue[@]:1}")
  [ -n "${seen[$f]:-}" ] && continue
  seen[$f]=1
  [ -e "$f" ] || continue
  while read -r d; do
    [ -n "$d" ] && [ -z "${seen[$d]:-}" ] && queue+=("$d")
  done < <(ldd "$f" 2>/dev/null | awk '{print $3}' | grep '^/' || true)
done
for f in "${!seen[@]}"; do
  case "$f" in /opt/rocm/*) cp -fL "$f" "$OUT"/ ;; esac
done
# host libs commonly absent from the Steam runtime
for n in libglog.so.2 libfmt.so.12 libnuma.so.1 libdrm.so.2 libdrm_amdgpu.so.1 \
         libelf.so.1 libgflags.so.2.2 libzstd.so.1; do
  p="$(ldconfig -p | awk -v n="$n" '$1==n{print $NF; exit}')"
  [ -n "$p" ] && cp -fL "$p" "$OUT"/ || true
done
for f in "$OUT"/libamdhip64.so.7 "$OUT"/libhsa-runtime64.so.1 "$OUT"/librocprofiler-register.so.0; do
  [ -f "$f" ] && (command -v patchelf >/dev/null && patchelf --set-rpath '$ORIGIN' "$f") || true
done
echo "rocm-libs ready: $OUT"
