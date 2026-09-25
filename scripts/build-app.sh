#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(dirname -- "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/ClariDiff.app"

cd "$PROJECT_DIR"
swift build -c release --product ClariDiffApp

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/.build/release/ClariDiffApp" "$APP_DIR/Contents/MacOS/ClariDiff"
cp "$PROJECT_DIR/Config/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Config/ClariDiff.icns" "$APP_DIR/Contents/Resources/ClariDiff.icns"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
