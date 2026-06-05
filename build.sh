#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="NotchDrop"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"

echo "▸ Building ${APP_NAME} (release)..."
swift build -c release --disable-sandbox 2>&1 | sed 's/^/  /'

echo "▸ Creating .app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "▸ Copying binary..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

echo "▸ Copying Info.plist..."
cp "Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

echo "▸ Copying app icon..."
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -f "MenuBarIcon.png" ]; then
    cp "MenuBarIcon.png" "${APP_BUNDLE}/Contents/Resources/"
fi

echo ""
echo "✅  ${APP_BUNDLE} created."
echo "   Run: open \"${APP_BUNDLE}\""
echo "   Or:  ./${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
