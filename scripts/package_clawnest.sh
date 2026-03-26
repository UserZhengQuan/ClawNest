#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClawNest"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/$APP_NAME.app"
ZIP_PATH="$ROOT/dist/$APP_NAME.zip"
SKIP_ZIP="${SKIP_ZIP:-0}"
DOWNLOADS_DIR="$HOME/Downloads"
DOWNLOADS_APP_DIR="$DOWNLOADS_DIR/$APP_NAME.app"
DOWNLOADS_ZIP_PATH="$DOWNLOADS_DIR/$APP_NAME.zip"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
INFO_PLIST_SOURCE="$ROOT/packaging/$APP_NAME-Info.plist"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "Building $APP_NAME (release)..."
swift build -c release --product "$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Expected executable not found: $EXECUTABLE" >&2
  exit 1
fi

echo "Creating app bundle..."
rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$MACOS_DIR"
cp -f "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"
cp -f "$INFO_PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"
xattr -cr "$APP_DIR"

echo "Applying ad-hoc signature..."
codesign --force --deep --sign - "$APP_DIR"

if [[ "$SKIP_ZIP" != "1" ]]; then
  echo "Creating zip archive..."
  ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
fi

echo "Syncing packaged artifacts to Downloads..."
mkdir -p "$DOWNLOADS_DIR"
ditto "$APP_DIR" "$DOWNLOADS_APP_DIR"

if [[ "$SKIP_ZIP" != "1" ]]; then
  cp -f "$ZIP_PATH" "$DOWNLOADS_ZIP_PATH"
fi

echo
echo "Packaged app:"
echo "  $APP_DIR"
echo "Downloads app:"
echo "  $DOWNLOADS_APP_DIR"

if [[ "$SKIP_ZIP" != "1" ]]; then
  echo "Zip archive:"
  echo "  $ZIP_PATH"
  echo "Downloads zip:"
  echo "  $DOWNLOADS_ZIP_PATH"
fi
