#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$ROOT_DIR/general/pomodoro/Sources"
ICON_FILE="$ROOT_DIR/general/pomodoro/Resources/AppIcon.icns"
APP_BUNDLE="$ROOT_DIR/dist/Pomo.app"
IDENTITY="${SIGNING_IDENTITY:--}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCHITECTURE="$(uname -m)"
INSTALL=false

usage() {
  echo "usage: $0 [--universal] [--install] [--output /path/Pomo.app] [--sign identity]"
  echo "Default: native architecture, ad hoc signature for local development."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --universal) ARCHITECTURE=universal; shift ;;
    --install) INSTALL=true; shift ;;
    --output|--sign)
      [[ $# -ge 2 && -n "$2" ]] || { usage >&2; exit 2; }
      if [[ "$1" == --output ]]; then APP_BUNDLE="$2"; else IDENTITY="$2"; fi
      shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ "$(uname -s)" == Darwin ]] || { echo "Building Pomo requires macOS." >&2; exit 1; }
[[ -f "$ROOT_DIR/VERSION" ]] || { echo "VERSION is missing." >&2; exit 1; }
VERSION="$(tr -d '\r\n' < "$ROOT_DIR/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must contain a numeric major.minor.patch version." >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "BUILD_NUMBER must be a positive integer." >&2; exit 1; }
[[ -f "$ICON_FILE" ]] || { echo "App icon missing: general/pomodoro/Resources/AppIcon.icns" >&2; exit 1; }
[[ "$APP_BUNDLE" == /*/Pomo.app ]] || { echo "--output must be an absolute path ending in /Pomo.app." >&2; exit 2; }
[[ "$ARCHITECTURE" == arm64 || "$ARCHITECTURE" == x86_64 || "$ARCHITECTURE" == universal ]] || { echo "Unsupported architecture: $ARCHITECTURE" >&2; exit 1; }

# Stage the bundle so a compile or signing failure cannot damage a previous build.
mkdir -p "$ROOT_DIR/build" "$(dirname "$APP_BUNDLE")"
STAGING="$(mktemp -d "$ROOT_DIR/build/app.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
STAGED_APP="$STAGING/Pomo.app"
CONTENTS="$STAGED_APP/Contents"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SOURCES=("$SOURCE_DIR/Core.swift" "$SOURCE_DIR/AppDelegate.swift" "$SOURCE_DIR/main.swift")
COMPILE_ARGS=(-O -sdk "$SDK" -module-cache-path "$ROOT_DIR/build/module-cache")
if [[ "$IDENTITY" == - ]]; then COMPILE_ARGS+=(-D POMO_DEVELOPMENT); fi

compile() {
  xcrun swiftc "${COMPILE_ARGS[@]}" -target "$1-apple-macos13.0" \
    "${SOURCES[@]}" -o "$2"
}

if [[ "$ARCHITECTURE" == universal ]]; then
  compile arm64 "$STAGING/Pomo-arm64"
  compile x86_64 "$STAGING/Pomo-x86_64"
  xcrun lipo -create "$STAGING/Pomo-arm64" "$STAGING/Pomo-x86_64" -output "$CONTENTS/MacOS/Pomo"
  xcrun lipo "$CONTENTS/MacOS/Pomo" -verify_arch arm64
  xcrun lipo "$CONTENTS/MacOS/Pomo" -verify_arch x86_64
else
  compile "$ARCHITECTURE" "$CONTENTS/MacOS/Pomo"
fi
/usr/bin/ditto "$ICON_FILE" "$CONTENTS/Resources/AppIcon.icns"

CHANNEL=development
[[ "$IDENTITY" == - ]] || CHANNEL=signed
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Pomo</string>
  <key>CFBundleDisplayName</key><string>Pomo</string>
  <key>CFBundleExecutable</key><string>Pomo</string>
  <key>CFBundleIdentifier</key><string>com.hrithik.pomo</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Hrithik Saini. MIT License.</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>PomoDistributionChannel</key><string>$CHANNEL</string>
</dict>
</plist>
PLIST
/usr/bin/plutil -lint "$CONTENTS/Info.plist"

SIGN_ARGS=(--force --sign "$IDENTITY" --identifier com.hrithik.pomo)
if [[ "$IDENTITY" != - ]]; then SIGN_ARGS+=(--options runtime --timestamp); fi
if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then SIGN_ARGS+=(--keychain "$SIGNING_KEYCHAIN"); fi
/usr/bin/codesign "${SIGN_ARGS[@]}" "$STAGED_APP"
/usr/bin/codesign --verify --strict --verbose=2 "$STAGED_APP"

# Refuse to replace a directory that is not an existing Pomo application.
if [[ -e "$APP_BUNDLE" ]]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)
  [[ "$EXISTING_ID" == com.hrithik.pomo ]] || { echo "Output exists and is not a Pomo bundle; build stopped." >&2; exit 1; }
  rm -rf "$APP_BUNDLE"
fi
mv "$STAGED_APP" "$APP_BUNDLE"
echo "Built $APP_BUNDLE ($VERSION, $ARCHITECTURE, $CHANNEL)"
if [[ "$IDENTITY" == - ]]; then
  echo "Development build: ad hoc signed; not notarized for public distribution."
fi

if "$INSTALL"; then
  INSTALL_DIR="$HOME/Applications"
  mkdir -p "$INSTALL_DIR"
  INSTALLED_APP="$INSTALL_DIR/Pomo.app"
  if [[ -e "$INSTALLED_APP" ]]; then
    EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$INSTALLED_APP/Contents/Info.plist" 2>/dev/null || true)
    [[ "$EXISTING_ID" == com.hrithik.pomo ]] || { echo "An unrelated Pomo.app exists; installation stopped." >&2; exit 1; }
    rm -rf "$INSTALLED_APP"
  fi
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP"
  echo "Installed $INSTALLED_APP"
fi
