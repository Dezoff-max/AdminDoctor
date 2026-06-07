#!/bin/bash
set -euo pipefail

APP_NAME="AdminDoctor"
VOLUME_NAME="AdminDoctor"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_ICON="$ROOT_DIR/Resources/Icons/AdminDoctorDMG.icns"
INSTALL_README="$ROOT_DIR/Resources/Install/Install AdminDoctor.txt"

if [[ ! -f "$DMG_ICON" ]]; then
  bash "$ROOT_DIR/script/generate_icons.sh"
fi

mkdir -p "$DIST_DIR"
find "$DIST_DIR" -maxdepth 1 -type d -name "$APP_NAME [0-9]*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME [0-9]*.dmg" -delete
find "$DIST_DIR" -maxdepth 1 -type d -name "AdminDoc*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "AdminDoc*.dmg" -delete

bash "$ROOT_DIR/script/build_and_run.sh" --bundle-only

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"
trap 'rm -rf "$DMG_ROOT"' EXIT

cp -R "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

if [[ -f "$INSTALL_README" ]]; then
  cp "$INSTALL_README" "$DMG_ROOT/Install AdminDoctor.txt"
fi

if [[ -f "$DMG_ICON" ]]; then
  cp "$DMG_ICON" "$DMG_ROOT/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "$DMG_ROOT" || true
  elif [[ -x /Applications/Xcode.app/Contents/Developer/Tools/SetFile ]]; then
    /Applications/Xcode.app/Contents/Developer/Tools/SetFile -a C "$DMG_ROOT" || true
  fi
fi

set_dmg_file_icon() {
  local source_png="$ROOT_DIR/Resources/Icons/AdminDoctorIconSource.png"
  local tmp_icon
  local tmp_rsrc

  command -v sips >/dev/null 2>&1 || return 0
  command -v DeRez >/dev/null 2>&1 || return 0
  command -v Rez >/dev/null 2>&1 || return 0
  command -v SetFile >/dev/null 2>&1 || return 0
  [[ -f "$source_png" ]] || return 0

  tmp_icon="$(mktemp -t admindoctor-dmg-icon).png"
  tmp_rsrc="$(mktemp -t admindoctor-dmg-icon).rsrc"
  cp "$source_png" "$tmp_icon"

  if sips -i "$tmp_icon" >/dev/null 2>&1 &&
    DeRez -only icns "$tmp_icon" >"$tmp_rsrc" 2>/dev/null &&
    Rez -append "$tmp_rsrc" -o "$DMG_PATH" >/dev/null 2>&1; then
    SetFile -a C "$DMG_PATH" >/dev/null 2>&1 || true
  fi

  rm -f "$tmp_icon" "$tmp_rsrc"
}

/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

/usr/bin/xattr -d com.apple.provenance "$DMG_PATH" 2>/dev/null || true
/usr/bin/xattr -d com.apple.quarantine "$DMG_PATH" 2>/dev/null || true

set_dmg_file_icon

echo "$DMG_PATH"
