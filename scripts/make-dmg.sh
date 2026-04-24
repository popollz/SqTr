#!/usr/bin/env bash
# Build a Release .app and a compressed .dmg for lab distribution.
# Usage (from repo root): ./scripts/make-dmg.sh
# Optional: BUILD_UNIVERSAL=1 ./scripts/make-dmg.sh  (requires full Xcode with xcbuild for multi-arch Swift PM)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MARKETING_VERSION="$(grep 'static let marketingVersion' Sources/SeqTraceMac/AppInfo.swift | sed -n 's/.*"\([^"]*\)".*/\1/p')"
BUILD_NUMBER="$(grep 'static let build' Sources/SeqTraceMac/AppInfo.swift | sed -n 's/.*"\([^"]*\)".*/\1/p')"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

# Display name in Finder / About (spaces OK). Executable name stays SeqTraceMac (SwiftPM product).
DISPLAY_APP_NAME="Swift SeqTrace"

DIST="${ROOT}/dist"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/swiftseqtrace-stage.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

echo "==> ${DISPLAY_APP_NAME} — version ${MARKETING_VERSION} (build ${BUILD_NUMBER})"

echo "==> swift build -c release"
UNIVERSAL_BUILD_OK=0
if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
  if swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    echo "    (universal binary)"
    UNIVERSAL_BUILD_OK=1
  else
    echo "    Universal build failed (install full Xcode or unset BUILD_UNIVERSAL). Falling back to host arch only."
    swift build -c release
  fi
else
  swift build -c release
fi

# When building universally via xcbuild, outputs live under .build/apple/Products/Release
# and `swift build --show-bin-path` (without --arch flags) returns the host-arch path
# instead, so we need to look in the xcbuild location first.
if [[ "$UNIVERSAL_BUILD_OK" == "1" && -x "${ROOT}/.build/apple/Products/Release/SeqTraceMac" ]]; then
  BIN_DIR="${ROOT}/.build/apple/Products/Release"
else
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi
EXEC="${BIN_DIR}/SeqTraceMac"
BUNDLE="${BIN_DIR}/SeqTraceMac_SeqTraceMac.bundle"

if [[ ! -x "$EXEC" ]]; then
  echo "error: missing executable at $EXEC" >&2
  exit 1
fi

APP="${STAGE}/${DISPLAY_APP_NAME}.app"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

cp "$EXEC" "${APP}/Contents/MacOS/SeqTraceMac"
chmod +x "${APP}/Contents/MacOS/SeqTraceMac"

if [[ -d "$BUNDLE" ]]; then
  rm -rf "${APP}/Contents/Resources/$(basename "$BUNDLE")"
  cp -R "$BUNDLE" "${APP}/Contents/Resources/"
else
  echo "warning: resource bundle not found at $BUNDLE (Help → User Guide may be empty)" >&2
fi

# Ship the .icns at the bundle root so Finder / Dock / Launchpad pick it up.
ICNS_SRC="${ROOT}/Sources/SeqTraceMac/Resources/AppIcon.icns"
if [[ -f "$ICNS_SRC" ]]; then
  cp "$ICNS_SRC" "${APP}/Contents/Resources/AppIcon.icns"
  HAS_ICON=1
else
  echo "warning: AppIcon.icns missing at $ICNS_SRC (bundle will ship without a custom icon)" >&2
  HAS_ICON=0
fi

INFO_PLIST="${APP}/Contents/Info.plist"
cat > "$INFO_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${DISPLAY_APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>SeqTraceMac</string>
$( [[ "$HAS_ICON" == "1" ]] && echo "  <key>CFBundleIconFile</key>
  <string>AppIcon</string>" )
  <key>CFBundleIdentifier</key>
  <string>org.swiftseqtrace.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${DISPLAY_APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${MARKETING_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> ad-hoc codesign (for local Gatekeeper; use Developer ID for wider distribution)"
codesign --force --deep --sign - "${APP}" 2>/dev/null || {
  echo "warning: codesign failed (install Xcode Command Line Tools)" >&2
}

mkdir -p "$DIST"
DMG_ROOT="${STAGE}/dmgroot"
mkdir -p "$DMG_ROOT"
cp -R "${APP}" "${DMG_ROOT}/"
ln -sf /Applications "${DMG_ROOT}/Applications"

DMG_NAME="SwiftSeqTrace-${MARKETING_VERSION}-b${BUILD_NUMBER}.dmg"
DMG_PATH="${DIST}/${DMG_NAME}"

echo "==> creating ${DMG_PATH}"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${DISPLAY_APP_NAME} ${MARKETING_VERSION}" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -srcfolder "$DMG_ROOT" \
  -ov \
  "$DMG_PATH"

echo "==> done: ${DMG_PATH}"
ls -lh "$DMG_PATH"
