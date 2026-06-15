#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
OUT_DIR="${OUT_DIR:-$ROOT/dist}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/build/DerivedData}"
APP="$DERIVED_DATA/Build/Products/Release/MacVoice.app"
DMG="$OUT_DIR/MacVoice-$VERSION-arm64.dmg"

mkdir -p "$OUT_DIR"
rm -rf "$DERIVED_DATA" "$OUT_DIR/dmg-root" "$DMG"

BUILD_ARGS=(
  -project "$ROOT/MacVoice.xcodeproj"
  -scheme MacVoice
  -configuration Release
  -destination "platform=macOS,arch=arm64"
  -derivedDataPath "$DERIVED_DATA"
  ARCHS=arm64
)

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  BUILD_ARGS+=(
    CODE_SIGN_STYLE=Manual
    "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY"
    "DEVELOPMENT_TEAM=${APPLE_TEAM_ID:-}"
  )
else
  BUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${BUILD_ARGS[@]}" clean build

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

mkdir -p "$OUT_DIR/dmg-root"
cp -R "$APP" "$OUT_DIR/dmg-root/"
ln -s /Applications "$OUT_DIR/dmg-root/Applications"

hdiutil create \
  -volname "MacVoice" \
  -srcfolder "$OUT_DIR/dmg-root" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$OUT_DIR/dmg-root"

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
  xcrun stapler staple "$DMG"
fi

echo "$DMG"
