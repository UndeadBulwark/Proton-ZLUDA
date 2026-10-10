#!/usr/bin/env bash
#
# convert.sh — turn a Proton build (proton-cachyos-slr or GE-Proton) into "Proton-ZLUDA":
# a Proton tool that runs on the HOST (no container) and delivers ZLUDA's 32-bit/64-bit
# nvcuda (+ a HIP shim) so 32-bit PhysX / CUDA works on AMD GPUs via ROCm.
#
# Usage:
#   ./convert.sh <proton_dir_or_tarball> [out_dir]
#
# Env overrides:
#   ZLUDA_DIR     path to an extracted ZLUDA *Windows* build (contains nvcuda.dll, 32/nvcuda.dll,
#                 zluda64_server.exe). Default: ./payload/zluda, else auto-downloaded.
#   HIPWINE_LIB   path to hipwine's built lib/wine dir (contains x86_64-windows/amdhip64_7.dll
#                 and x86_64-unix/amdhip64_7.dll.so). Default: ./payload/hipwine/lib/wine, else built.
#   ROCM_LIBS     path to a dir with the ROCm lib closure. Default: ./payload/rocm-libs, else bundled.
#   TOOL_NAME     internal/display name of the produced tool. Default: ZludaProton
#   ZLUDA_VERSION pinned ZLUDA release tag for auto-download. Default: v7-preview.15
#
set -euo pipefail

TOOL_NAME="${TOOL_NAME:-ZludaProton}"
ZLUDA_VERSION="${ZLUDA_VERSION:-v7-preview.15}"
ZLUDA_ASSET="${ZLUDA_ASSET:-zluda-windows-86ec0a9.zip}"   # asset name in the pinned release

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/proton-zluda"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "[convert] $*"; }

[ $# -ge 1 ] || die "usage: $0 <proton_dir_or_tarball> [out_dir]"

SRC="$1"
OUT="${2:-}"

# --- resolve source -------------------------------------------------------
TMP=""
if [ -f "$SRC" ]; then
  case "$SRC" in
    *.tar.gz|*.tgz|*.tar.xz|*.tar.zst|*.tar)
      TMP="$(mktemp -d)"; log "extracting $SRC"
      tar -xf "$SRC" -C "$TMP" || die "failed to extract"
      # find the dir containing a 'proton' script
      SRC="$(find "$TMP" -maxdepth 3 -name proton -type f -printf '%h\n' | head -1)"
      ;;
    *.zip)
      TMP="$(mktemp -d)"; log "extracting $SRC"
      unzip -q "$SRC" -d "$TMP"
      SRC="$(find "$TMP" -maxdepth 3 -name proton -type f -printf '%h\n' | head -1)"
      ;;
  esac
fi
[ -d "$SRC" ] || die "source dir '$SRC' not found"
SRC="$(cd "$SRC" && pwd)"
[ -f "$SRC/proton" ] || die "'$SRC' does not look like a Proton build (no ./proton)"

VER="$(tr -d '\r\n' < "$SRC/version" 2>/dev/null || true)"
[ -n "$VER" ] || VER="unknown"
OUT="${OUT:-$(dirname "$SRC")/Proton-ZLUDA-$VER}"
OUT="$(mkdir -p "$OUT" && cd "$OUT" && pwd)"
log "source : $SRC  (version: $VER)"
log "output : $OUT"

# --- copy tree ------------------------------------------------------------
log "copying Proton tree (this is the big step)"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -a --reflink=auto "$SRC/." "$OUT/" 2>/dev/null || cp -a "$SRC/." "$OUT/"

# --- payload: ZLUDA -------------------------------------------------------
if [ -z "${ZLUDA_DIR:-}" ]; then
  if [ -d "$here/payload/zluda" ]; then ZLUDA_DIR="$here/payload/zluda"; fi
fi
if [ -z "${ZLUDA_DIR:-}" ]; then
  mkdir -p "$CACHE"; ZLUDA_DIR="$CACHE/zluda"
  if [ ! -f "$ZLUDA_DIR/nvcuda.dll" ]; then
    log "downloading ZLUDA $ZLUDA_VERSION"
    curl -fL --retry 3 -o "$CACHE/zluda.zip" \
      "https://github.com/vosen/ZLUDA/releases/download/$ZLUDA_VERSION/$ZLUDA_ASSET" \
      || die "ZLUDA download failed; set ZLUDA_DIR to an extracted ZLUDA Windows build"
    rm -rf "$CACHE/zx"; mkdir -p "$CACHE/zx"; unzip -q "$CACHE/zluda.zip" -d "$CACHE/zx"
    # normalize: find dir containing nvcuda.dll
    z="$(find "$CACHE/zx" -name nvcuda.dll -printf '%h\n' | head -1)"
    [ -n "$z" ] || die "could not locate ZLUDA in download"
    rm -rf "$ZLUDA_DIR"; mv "$z" "$ZLUDA_DIR"
  fi
fi
[ -f "$ZLUDA_DIR/nvcuda.dll" ] || die "ZLUDA_DIR ($ZLUDA_DIR) missing nvcuda.dll"
[ -f "$ZLUDA_DIR/32/nvcuda.dll" ] || die "ZLUDA_DIR ($ZLUDA_DIR) missing 32/nvcuda.dll"
log "ZLUDA  : $ZLUDA_DIR"

# --- payload: hipwine -----------------------------------------------------
if [ -z "${HIPWINE_LIB:-}" ]; then
  if [ -d "$here/payload/hipwine/lib/wine" ]; then HIPWINE_LIB="$here/payload/hipwine/lib/wine"; fi
fi
if [ -z "${HIPWINE_LIB:-}" ] || [ ! -f "$HIPWINE_LIB/x86_64-unix/amdhip64_7.dll.so" ]; then
  log "hipwine not found; building it"
  "$here/scripts/build-hipwine.sh" "$CACHE/hipwine"
  HIPWINE_LIB="$CACHE/hipwine/lib/wine"
fi
[ -f "$HIPWINE_LIB/x86_64-unix/amdhip64_7.dll.so" ] || die "hipwine build missing amdhip64_7.dll.so"
log "hipwine: $HIPWINE_LIB"

# --- payload: rocm libs ---------------------------------------------------
if [ -z "${ROCM_LIBS:-}" ]; then
  if [ -d "$here/payload/rocm-libs" ]; then ROCM_LIBS="$here/payload/rocm-libs"; fi
fi
if [ -z "${ROCM_LIBS:-}" ] || [ ! -f "$ROCM_LIBS/libamdhip64.so.7" ]; then
  log "bundling ROCm libs"
  ROCM_LIBS="$CACHE/rocm-libs"; "$here/scripts/bundle-rocm.sh" "$ROCM_LIBS"
fi
[ -f "$ROCM_LIBS/libamdhip64.so.7" ] || die "rocm-libs missing libamdhip64.so.7"
log "rocm   : $ROCM_LIBS"

LIB="$OUT/files/lib/wine"
DP="$OUT/files/share/default_pfx"

# --- 1. patch proton script: force native nvcuda --------------------------
log "patching proton script"
PROTON="$OUT/proton"
if grep -q 'append_to_env_str(self.env, "WINEDLLOVERRIDES", s, ";")' "$PROTON"; then
  if ! grep -q 'proton-zluda' "$PROTON"; then
    perl -0pi -e 's/(\Qappend_to_env_str(self.env, "WINEDLLOVERRIDES", s, ";")\E)/$1\n        append_to_env_str(self.env, "WINEDLLOVERRIDES", "nvcuda=n", ";")  # proton-zluda/' "$PROTON"
  fi
else
  log "WARNING: could not find WINEDLLOVERRIDES append line; nvcuda override NOT added."
  log "         Review $PROTON manually."
fi

# --- 2. toolmanifest: drop require_tool_appid (run on host, not the container)
log "patching toolmanifest"
for m in toolmanifest.vdf toolmanifest_x86_64.vdf toolmanifest_runtime.vdf; do
  [ -f "$OUT/$m" ] && sed -i '/require_tool_appid/d' "$OUT/$m"
done

# --- 3. nvcuda: ZLUDA into default_pfx + registry override ----------------
log "installing ZLUDA nvcuda into default_pfx"
rm -f "$DP/drive_c/windows/system32/nvcuda.dll" "$DP/drive_c/windows/syswow64/nvcuda.dll"
cp -f "$ZLUDA_DIR/nvcuda.dll"    "$DP/drive_c/windows/system32/nvcuda.dll"
cp -f "$ZLUDA_DIR/32/nvcuda.dll" "$DP/drive_c/windows/syswow64/nvcuda.dll"
[ -f "$DP/user.reg" ] && sed -i 's/^"nvcuda"="disabled"/"nvcuda"="native"/' "$DP/user.reg" || true

# --- 4. hipwine + ROCm libs (self-contained) ------------------------------
log "installing hipwine + ROCm libs into the tool"
cp -f "$HIPWINE_LIB/x86_64-windows/amdhip64_7.dll"    "$LIB/x86_64-windows/amdhip64_7.dll"
cp -f "$HIPWINE_LIB/x86_64-unix/amdhip64_7.dll.so"    "$LIB/x86_64-unix/amdhip64_7.dll.so"
rm -rf "$OUT/zluda-libs"; mkdir -p "$OUT/zluda-libs"
cp -aL "$ROCM_LIBS"/. "$OUT/zluda-libs"/
patchelf --set-rpath '$ORIGIN/../../../../zluda-libs' "$LIB/x86_64-unix/amdhip64_7.dll.so"
for f in "$OUT/zluda-libs"/libhsa-runtime64.so.1 "$OUT/zluda-libs"/librocprofiler-register.so.0 "$OUT/zluda-libs"/libamdhip64.so.7; do
  [ -f "$f" ] && patchelf --set-rpath '$ORIGIN' "$f" || true
done

# --- 5. ZLUDA dir inside the tool (for ZLUDA64_PATH) ----------------------
log "embedding ZLUDA (server + DLLs) for the 32-bit shim"
rm -rf "$OUT/zluda"; cp -aL "$ZLUDA_DIR" "$OUT/zluda"

# --- 6. user_settings.py (relocatable) ------------------------------------
cat > "$OUT/user_settings.py" <<'EOF'
# Generated by Proton-ZLUDA convert.sh
# ZLUDA64_PATH is resolved relative to this file, so the tool is relocatable (drag & drop).
import os
_zluda = os.path.join(os.path.dirname(os.path.abspath(__file__)), "zluda")
user_settings = {
    "ZLUDA64_PATH": "Z:" + _zluda.replace("/", "\\"),
    "PROTON_LOG": "1",
}
EOF

# --- 7. tool identity -----------------------------------------------------
VDF="$OUT/compatibilitytool.vdf"
if [ -f "$VDF" ]; then
  # replace any existing internal name + display name
  python3 - "$VDF" "$TOOL_NAME" <<'PY'
import re, sys
p, name = sys.argv[1], sys.argv[2]
s = open(p).read()
s = re.sub(r'"compat_tools"\s*\{\s*\{?\s*"[^"]+"', '"compat_tools"\n  {\n    "%s"' % name, s, count=1)
s = re.sub(r'"display_name"\s*"[^"]*"', '"display_name" "%s"' % name, s, count=1)
open(p, "w").write(s)
PY
else
  cat > "$VDF" <<EOF
"compatibilitytools"
{
  "compat_tools"
  {
    "$TOOL_NAME"
    {
      "install_path" "."
      "display_name" "$TOOL_NAME"
      "from_oslist" "windows"
      "to_oslist" "linux"
    }
  }
}
EOF
fi

rm -rf "$TMP" 2>/dev/null || true
log "done -> $OUT"
echo
echo "Install it:"
echo "  cp -a '$OUT' ~/.local/share/Steam/compatibilitytools.d/$TOOL_NAME"
echo "Then Steam > game > Properties > Compatibility > force '$TOOL_NAME' and launch with PhysX set to High."
