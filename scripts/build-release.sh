#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
STAGING_DIR="$DIST_DIR/dmg-root"
APP_DIR="$STAGING_DIR/ClariDiff.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Config/Info.plist")"
DMG_PATH="$DIST_DIR/ClariDiff-$VERSION-Universal.dmg"
CLI_PATH="$DIST_DIR/claridiff-$VERSION-macos-universal"

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR"
rm -f "$DMG_PATH" "$CLI_PATH" "$DIST_DIR/SHA256SUMS"

(cd "$PROJECT_DIR" && swift build -c release --arch arm64)
ARM_BIN_DIR="$(cd "$PROJECT_DIR" && swift build -c release --arch arm64 --show-bin-path)"
(cd "$PROJECT_DIR" && swift build -c release --arch x86_64)
X64_BIN_DIR="$(cd "$PROJECT_DIR" && swift build -c release --arch x86_64 --show-bin-path)"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
lipo -create \
    "$ARM_BIN_DIR/ClariDiffApp" \
    "$X64_BIN_DIR/ClariDiffApp" \
    -output "$APP_DIR/Contents/MacOS/ClariDiff"
lipo -create \
    "$ARM_BIN_DIR/claridiff" \
    "$X64_BIN_DIR/claridiff" \
    -output "$CLI_PATH"

cp "$PROJECT_DIR/Config/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Config/ClariDiff.icns" "$APP_DIR/Contents/Resources/ClariDiff.icns"
chmod +x "$APP_DIR/Contents/MacOS/ClariDiff" "$CLI_PATH"

codesign --force --deep --sign - "$APP_DIR"
codesign --force --sign - "$CLI_PATH"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "ClariDiff" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

(
    cd "$DIST_DIR"
    shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$CLI_PATH")" > SHA256SUMS
)

echo "Built $DMG_PATH"
echo "Built $CLI_PATH"
echo "Checksums: $DIST_DIR/SHA256SUMS"
