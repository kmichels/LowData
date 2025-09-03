#!/bin/bash

# Build and sign LowData for distribution with Developer ID certificate

set -e

# Configuration
APP_NAME="LowData"
BUNDLE_ID="com.tonalphoto.tech.LowData"
DEVELOPER_ID="Developer ID Application: Konrad Michels (85QL287QYW)"
BUILD_DIR="build_release"
HELPER_NAME="com.lowdata.helper"

echo "Building LowData for Developer ID distribution..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the helper first (if not already built)
if [ ! -f "build/$HELPER_NAME" ]; then
    echo "Building helper tool first..."
    ./build_helper.sh
fi

# Build the app with Release configuration
echo "Building app with xcodebuild..."
xcodebuild -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="85QL287QYW" \
    build

# Find the built app
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

# Copy helper to app bundle's Library/LaunchServices
echo "Embedding helper tool..."
LAUNCH_SERVICES_DIR="$APP_PATH/Contents/Library/LaunchServices"
mkdir -p "$LAUNCH_SERVICES_DIR"
cp "build/$HELPER_NAME" "$LAUNCH_SERVICES_DIR/"

# Sign the app (deep sign to include helper)
echo "Signing app bundle with Developer ID..."
codesign --force \
    --deep \
    --sign "$DEVELOPER_ID" \
    --entitlements "LowData/LowData.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_PATH"

# Verify the signature
echo ""
echo "Verifying app signature..."
codesign -dvvv "$APP_PATH"

echo ""
echo "Verifying helper signature..."
codesign -dvvv "$APP_PATH/Contents/Library/LaunchServices/$HELPER_NAME"

# Check SMJobBless requirements
echo ""
echo "Checking SMJobBless requirements..."
echo "App Info.plist SMPrivilegedExecutables:"
plutil -extract SMPrivilegedExecutables xml1 -o - "$APP_PATH/Contents/Info.plist" || echo "Not found - need to add to Info.plist"

echo ""
echo "Build complete!"
echo "App location: $APP_PATH"
echo ""
echo "To test the helper installation:"
echo "1. Run: open '$APP_PATH'"
echo "2. Go to Preferences > Blocking Rules"
echo "3. Click 'Install Helper' if prompted"
echo "4. Enter admin password"
echo ""
echo "To verify helper installation:"
echo "ls -la /Library/PrivilegedHelperTools/ | grep $HELPER_NAME"