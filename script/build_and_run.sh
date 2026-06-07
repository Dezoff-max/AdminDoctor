#!/bin/bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="AdminDoctor"
BUNDLE_ID="dev.admindoctor.AdminDoctor"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_LAUNCH_SERVICES="$APP_CONTENTS/Library/LaunchServices"
APP_LAUNCH_DAEMONS="$APP_CONTENTS/Library/LaunchDaemons"
APP_BINARY="$APP_MACOS/$APP_NAME"
HELPER_NAME="AdminDoctorPrivilegedHelper"
HELPER_BINARY="$APP_LAUNCH_SERVICES/$HELPER_NAME"
HELPER_PLIST_SOURCE="$ROOT_DIR/Resources/PrivilegedHelper/dev.admindoctor.AdminDoctorPrivilegedHelper.plist"
HELPER_PLIST_DEST="$APP_LAUNCH_DAEMONS/dev.admindoctor.AdminDoctorPrivilegedHelper.plist"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/Icons/AdminDoctor.icns"
ICON_SCRIPT="$ROOT_DIR/script/generate_icons.sh"
LOCALIZATION_ROOT="$ROOT_DIR/Sources/AdminDoctor/Resources"

cd "$ROOT_DIR"

mkdir -p "$DIST_DIR"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
find "$DIST_DIR" -maxdepth 1 -type d -name "$APP_NAME [0-9]*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "$APP_NAME [0-9]*.dmg" -delete
find "$DIST_DIR" -maxdepth 1 -type d -name "AdminDoc*.app" -prune -exec rm -rf {} +
find "$DIST_DIR" -maxdepth 1 -type f -name "AdminDoc*.dmg" -delete

if [[ ! -f "$APP_ICON_SOURCE" ]]; then
  bash "$ICON_SCRIPT"
fi

swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
BUILD_HELPER_BINARY="$BUILD_DIR/$HELPER_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_LAUNCH_SERVICES" "$APP_LAUNCH_DAEMONS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$BUILD_HELPER_BINARY" ]]; then
  cp "$BUILD_HELPER_BINARY" "$HELPER_BINARY"
  chmod +x "$HELPER_BINARY"
fi

if [[ -f "$HELPER_PLIST_SOURCE" ]]; then
  cp "$HELPER_PLIST_SOURCE" "$HELPER_PLIST_DEST"
fi

if [[ -f "$APP_ICON_SOURCE" ]]; then
  cp "$APP_ICON_SOURCE" "$APP_RESOURCES/AdminDoctor.icns"
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
  <string>AdminDoctor</string>
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

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  CODESIGN_TIMESTAMP_ARG="${CODE_SIGN_TIMESTAMP_ARG:---timestamp=none}"
  if [[ -f "$HELPER_BINARY" ]]; then
    /usr/bin/codesign --force --options runtime "$CODESIGN_TIMESTAMP_ARG" --sign "$CODE_SIGN_IDENTITY" "$HELPER_BINARY"
  fi
  /usr/bin/codesign --force --options runtime "$CODESIGN_TIMESTAMP_ARG" --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
fi

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
