#!/usr/bin/env bash
# Regenerate Sources/SeqTraceMac/Resources/AppIcon.icns from AppIcon-1024.png.
# Run this whenever the master 1024x1024 PNG changes.
# Usage (from repo root): ./scripts/make-appicon.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="${ROOT}/Sources/SeqTraceMac/Resources"
MASTER="${RES}/AppIcon-1024.png"
OUT="${RES}/AppIcon.icns"

if [[ ! -f "$MASTER" ]]; then
  echo "error: master icon missing at $MASTER" >&2
  exit 1
fi

# Sanity-check master dimensions (must be 1024x1024 so the @2x 512 slot fills cleanly).
W=$(sips -g pixelWidth  "$MASTER" | tail -1 | awk '{print $2}')
H=$(sips -g pixelHeight "$MASTER" | tail -1 | awk '{print $2}')
if [[ "$W" != "1024" || "$H" != "1024" ]]; then
  echo "error: master icon must be 1024x1024 (got ${W}x${H})" >&2
  exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/appicon-stage.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

ICONSET="${STAGE}/AppIcon.iconset"
mkdir -p "$ICONSET"

gen() { # size, filename
  sips -z "$1" "$1" "$MASTER" --out "${ICONSET}/$2" >/dev/null
}

gen   16 icon_16x16.png
gen   32 icon_16x16@2x.png
gen   32 icon_32x32.png
gen   64 icon_32x32@2x.png
gen  128 icon_128x128.png
gen  256 icon_128x128@2x.png
gen  256 icon_256x256.png
gen  512 icon_256x256@2x.png
gen  512 icon_512x512.png
gen 1024 icon_512x512@2x.png

# iconutil requires RGBA PNGs. sips outputs RGB, so re-encode via Python.
# Uses the system python3 and Pillow from a scratch venv (avoids polluting the user env).
VENV="${STAGE}/venv"
python3 -m venv "$VENV"
"${VENV}/bin/pip" install --quiet Pillow
"${VENV}/bin/python" - "$ICONSET" <<'PY'
import sys, os
from PIL import Image
iconset = sys.argv[1]
for name in os.listdir(iconset):
    if name.endswith(".png"):
        p = os.path.join(iconset, name)
        Image.open(p).convert("RGBA").save(p, "PNG")
PY

iconutil --convert icns --output "$OUT" "$ICONSET"
echo "==> wrote $OUT ($(wc -c <"$OUT") bytes)"
