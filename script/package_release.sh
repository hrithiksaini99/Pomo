#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist/releases"
ARCHITECTURE="$(uname -m)"
DEVELOPMENT=false
BUILD_ARGS=()

usage() {
  echo "usage: $0 [--universal] [--development] [--output-dir /path/to/releases]"
  echo "Public release: requires SIGNING_IDENTITY and NOTARY_PROFILE."
  echo "--development: create explicitly labeled, ad hoc signed test archives."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --universal) ARCHITECTURE=universal; BUILD_ARGS+=(--universal); shift ;;
    --development) DEVELOPMENT=true; shift ;;
    --output-dir)
      [[ $# -ge 2 && "$2" == /* ]] || { usage >&2; exit 2; }
      OUTPUT_DIR="$2"; shift 2
      ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ "$(uname -s)" == Darwin ]] || { echo "Packaging Pomo requires macOS." >&2; exit 1; }
[[ -f "$ROOT_DIR/VERSION" ]] || { echo "VERSION is missing." >&2; exit 1; }
VERSION="$(tr -d '\r\n' < "$ROOT_DIR/VERSION")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "VERSION must contain major.minor.patch." >&2; exit 1; }
BUILD_NUMBER="${BUILD_NUMBER:-1}"
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "BUILD_NUMBER must be a positive integer." >&2; exit 1; }

CHANNEL=release
IDENTITY="${SIGNING_IDENTITY:-}"
if "$DEVELOPMENT"; then
  CHANNEL=development
  IDENTITY=-
else
  [[ -n "$IDENTITY" && "$IDENTITY" != - ]] || { echo "Public release stopped: set SIGNING_IDENTITY to your Developer ID Application identity, or use --development." >&2; exit 1; }
  [[ -n "${NOTARY_PROFILE:-}" ]] || { echo "Public release stopped: set NOTARY_PROFILE to an existing notarytool Keychain credential profile." >&2; exit 1; }
  xcrun --find notarytool >/dev/null
  xcrun --find stapler >/dev/null
fi

BASE="Pomo-$VERSION-macos-$ARCHITECTURE"
if "$DEVELOPMENT"; then BASE="$BASE-development"; fi
mkdir -p "$ROOT_DIR/build" "$OUTPUT_DIR"
for EXTENSION in zip dmg release.json SHA256SUMS.txt; do
  [[ ! -e "$OUTPUT_DIR/$BASE.$EXTENSION" ]] || { echo "Artifact already exists: $BASE.$EXTENSION. Use a fresh output directory or bump VERSION." >&2; exit 1; }
done
WORK_DIR="$(mktemp -d "$ROOT_DIR/build/package.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
APP_BUNDLE="$WORK_DIR/Pomo.app"
BUILD_ARGS+=(--output "$APP_BUNDLE" --sign "$IDENTITY")
"$ROOT_DIR/build.sh" "${BUILD_ARGS[@]}"

NOTARY_ARGS=(--keychain-profile "${NOTARY_PROFILE:-}")
if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then NOTARY_ARGS+=(--keychain "$NOTARY_KEYCHAIN"); fi
NOTARY_LOG_DIR="$ROOT_DIR/build/notarization"

notarize() {
  local ARCHIVE="$1" KIND="$2" STATUS RESPONSE
  mkdir -p "$NOTARY_LOG_DIR"
  RESPONSE="$NOTARY_LOG_DIR/$BASE-$BUILD_NUMBER-$KIND.json"
  echo "Submitting $KIND for notarization."
  xcrun notarytool submit "$ARCHIVE" "${NOTARY_ARGS[@]}" --wait --timeout 30m --output-format json > "$RESPONSE"
  STATUS=$(/usr/bin/plutil -extract status raw -o - "$RESPONSE")
  [[ "$STATUS" == Accepted ]] || { echo "Notarization $STATUS; distribution stopped. Response saved in build/notarization." >&2; exit 1; }
}

if ! "$DEVELOPMENT"; then
  SIGNATURE=$(/usr/bin/codesign --display --verbose=4 "$APP_BUNDLE" 2>&1)
  [[ "$SIGNATURE" == *"Authority=Developer ID Application:"* ]] || { echo "Public release stopped: the app is not signed with Developer ID Application." >&2; exit 1; }
  [[ "$SIGNATURE" == *"runtime"* ]] || { echo "Public release stopped: hardened runtime is missing." >&2; exit 1; }
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$WORK_DIR/notarization.zip"
  notarize "$WORK_DIR/notarization.zip" app
  xcrun stapler staple "$APP_BUNDLE"
  xcrun stapler validate "$APP_BUNDLE"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$APP_BUNDLE"
fi

# The ZIP is created after stapling so its application includes the ticket.
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$WORK_DIR/$BASE.zip"
mkdir -p "$WORK_DIR/disk"
/usr/bin/ditto "$APP_BUNDLE" "$WORK_DIR/disk/Pomo.app"
ln -s /Applications "$WORK_DIR/disk/Applications"
cat > "$WORK_DIR/disk/Read Me.txt" <<'TEXT'
Pomo

Drag Pomo.app into Applications, then open it.
Click the timer icon in your menu bar to start a focus session.
Allow notifications to receive completion banners.

Requires macOS 13 or later. No account, analytics, or network connection.
TEXT
VOLUME_NAME="Pomo $VERSION"
if "$DEVELOPMENT"; then
  VOLUME_NAME="$VOLUME_NAME Development"
  cat >> "$WORK_DIR/disk/Read Me.txt" <<'TEXT'

DEVELOPMENT BUILD
This build is ad hoc signed and has not been notarized by Apple.
It is intended for development and testing, not public distribution.
Build from source to test locally. Do not disable Gatekeeper.
TEXT
fi
/usr/bin/hdiutil create -volname "$VOLUME_NAME" -srcfolder "$WORK_DIR/disk" \
  -format UDZO -fs HFS+ "$WORK_DIR/$BASE.dmg"
/usr/bin/hdiutil verify "$WORK_DIR/$BASE.dmg"

NOTARIZED=false
if ! "$DEVELOPMENT"; then
  DMG_SIGN_ARGS=(--force --sign "$IDENTITY" --timestamp)
  if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then DMG_SIGN_ARGS+=(--keychain "$SIGNING_KEYCHAIN"); fi
  /usr/bin/codesign "${DMG_SIGN_ARGS[@]}" "$WORK_DIR/$BASE.dmg"
  /usr/bin/codesign --verify --strict "$WORK_DIR/$BASE.dmg"
  notarize "$WORK_DIR/$BASE.dmg" dmg
  xcrun stapler staple "$WORK_DIR/$BASE.dmg"
  xcrun stapler validate "$WORK_DIR/$BASE.dmg"
  NOTARIZED=true
fi
/usr/bin/codesign --verify --strict --verbose=2 "$APP_BUNDLE"
cat > "$WORK_DIR/$BASE.release.json" <<JSON
{
  "product": "Pomo",
  "version": "$VERSION",
  "buildNumber": "$BUILD_NUMBER",
  "bundleIdentifier": "com.hrithik.pomo",
  "architecture": "$ARCHITECTURE",
  "minimumMacOS": "13.0",
  "channel": "$CHANNEL",
  "notarized": $NOTARIZED
}
JSON
(
  cd "$WORK_DIR"
  /usr/bin/shasum -a 256 "$BASE.zip" "$BASE.dmg" "$BASE.release.json" > "$BASE.SHA256SUMS.txt"
  /usr/bin/shasum -a 256 -c "$BASE.SHA256SUMS.txt"
)
for EXTENSION in zip dmg release.json SHA256SUMS.txt; do
  mv "$WORK_DIR/$BASE.$EXTENSION" "$OUTPUT_DIR/$BASE.$EXTENSION"
done
echo "Packaged $BASE in $OUTPUT_DIR"
if "$DEVELOPMENT"; then
  echo "Development artifacts only: ad hoc signed and not notarized."
else
  echo "Developer ID signed; app and disk image notarized, stapled, and validated."
fi
