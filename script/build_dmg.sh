#!/bin/bash
set -euo pipefail

APP_NAME="AdminDoc"
VOLUME_NAME="AdminDoc"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_ICON="$ROOT_DIR/Resources/Icons/AdminDocDMG.icns"

if [[ ! -f "$DMG_ICON" ]]; then
  bash "$ROOT_DIR/script/generate_icons.sh"
fi

mkdir -p "$DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -type d -name "$APP_NAME [0-9]*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME [0-9]*.dmg" -delete

bash "$ROOT_DIR/script/build_and_run.sh" --bundle-only

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
trap 'rm -rf "$DMG_ROOT"' EXIT

cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

if [[ -f "$DMG_ICON" ]]; then
  cp "$DMG_ICON" "$DMG_ROOT/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$DMG_ROOT" || true
  elif [[ -x /Applications/Xcode.app/Contents/Developer/Tools/SetFile ]]; then
    /Applications/Xcode.app/Contents/Developer/Tools/SetFile -a C "$DMG_ROOT" || true
  fi
fi

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

/usr/bin/xattr -cr "$DMG_PATH" 2>/dev/null || true
/usr/bin/xattr -d com.apple.provenance "$DMG_PATH" 2>/dev/null || true

echo "$DMG_PATH"
