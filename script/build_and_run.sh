#!/bin/bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AdminDoc"
BUNDLE_ID="dev.admindoc.AdminDoc"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/Icons/AdminDoc.icns"
ICON_SCRIPT="$ROOT_DIR/script/generate_icons.sh"
LOCALIZATION_ROOT="$ROOT_DIR/Sources/AdminDoc/Resources"

cd "$ROOT_DIR"

mkdir -p "$DIST_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
find "$DIST_DIR" -maxdepth 1 -type d -name "$APP_NAME [0-9]*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME [0-9]*.dmg" -delete

if [[ ! -f "$APP_ICON_SOURCE" ]]; then
  bash "$ICON_SCRIPT"
fi

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AdminDoc.icns"
fi

if [[ -d "$LOCALIZATION_ROOT" ]]; then
  find "$LOCALIZATION_ROOT" -maxdepth 1 -type d -name "*.lproj" -exec cp -R {} "$APP_RESOURCES/" \;
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AdminDoc</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>ru</string>
  </array>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/xattr -cr "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.provenance "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/xattr -dr "com.apple.fileprovider.fpfs#P" "$APP_BUNDLE" 2>/dev/null || true

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --bundle-only|bundle)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--bundle-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
