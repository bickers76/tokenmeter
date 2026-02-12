#!/bin/bash
set -e

APP_NAME="TokenMeter"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🔨 Building release..."
swift build -c release

echo "📦 Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}"
mkdir -p "${RESOURCES}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "TokenMeter/Info.plist" "${CONTENTS}/Info.plist"

# Copy entitlements
cp "TokenMeter/TokenMeter.entitlements" "${CONTENTS}/"

# Create icon if it exists
if [ -f "TokenMeter/Assets/AppIcon.icns" ]; then
    cp "TokenMeter/Assets/AppIcon.icns" "${RESOURCES}/AppIcon.icns"
fi

# Sign
echo "🔏 Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Built: ${APP_BUNDLE}"
echo "   Run: open ${APP_BUNDLE}"
echo ""
echo "📋 To create DMG:"
echo "   hdiutil create -volname TokenMeter -srcfolder ${APP_BUNDLE} -ov -format UDZO TokenMeter.dmg"
