#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_ROOT="$ROOT_DIR/Resources/Icons"
SOURCE_ICON="$ICON_ROOT/AdminDocIconSource.png"
APP_ICONSET="$ICON_ROOT/AppIcon.iconset"
DMG_ICONSET="$ICON_ROOT/DMGIcon.iconset"
RENDER_SCRIPT="$ROOT_DIR/script/render_icon.swift"

if [[ ! -f "$SOURCE_ICON" ]]; then
  /usr/bin/swift "$RENDER_SCRIPT" "$SOURCE_ICON" >/dev/null
fi

if [[ ! -f "$SOURCE_ICON" ]]; then
  echo "missing source icon: $SOURCE_ICON" >&2
  exit 1
fi

rm -rf "$APP_ICONSET" "$DMG_ICONSET"
mkdir -p "$APP_ICONSET" "$DMG_ICONSET"

generate_iconset() {
  local iconset="$1"

  /usr/bin/sips -z 16 16 "$SOURCE_ICON" --out "$iconset/icon_16x16.png" >/dev/null
  /usr/bin/sips -z 32 32 "$SOURCE_ICON" --out "$iconset/icon_16x16@2x.png" >/dev/null
  /usr/bin/sips -z 32 32 "$SOURCE_ICON" --out "$iconset/icon_32x32.png" >/dev/null
  /usr/bin/sips -z 64 64 "$SOURCE_ICON" --out "$iconset/icon_32x32@2x.png" >/dev/null
  /usr/bin/sips -z 128 128 "$SOURCE_ICON" --out "$iconset/icon_128x128.png" >/dev/null
  /usr/bin/sips -z 256 256 "$SOURCE_ICON" --out "$iconset/icon_128x128@2x.png" >/dev/null
  /usr/bin/sips -z 256 256 "$SOURCE_ICON" --out "$iconset/icon_256x256.png" >/dev/null
  /usr/bin/sips -z 512 512 "$SOURCE_ICON" --out "$iconset/icon_256x256@2x.png" >/dev/null
  /usr/bin/sips -z 512 512 "$SOURCE_ICON" --out "$iconset/icon_512x512.png" >/dev/null
  /usr/bin/sips -z 1024 1024 "$SOURCE_ICON" --out "$iconset/icon_512x512@2x.png" >/dev/null
}

generate_iconset "$APP_ICONSET"
generate_iconset "$DMG_ICONSET"

/usr/bin/iconutil -c icns "$APP_ICONSET" -o "$ICON_ROOT/AdminDoc.icns"
/usr/bin/iconutil -c icns "$DMG_ICONSET" -o "$ICON_ROOT/AdminDocDMG.icns"

echo "Generated:"
echo "  $ICON_ROOT/AdminDoc.icns"
echo "  $ICON_ROOT/AdminDocDMG.icns"
