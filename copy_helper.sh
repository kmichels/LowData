#!/bin/bash

# Script to copy helper files to app bundle during build
# This ensures the helper persists through Xcode rebuilds

echo "Copying helper files to app bundle..."

# Get the app bundle path from Xcode environment
APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"

# Create LaunchDaemons directory
mkdir -p "${APP_BUNDLE}/Contents/Library/LaunchDaemons"

# Build helper if source is newer than binary
HELPER_SOURCE="${SRCROOT}/LowDataHelper/main.swift"
HELPER_BINARY="${SRCROOT}/LowData/LaunchDaemons/com.lowdata.helper.xpc"

PROTOCOL_SOURCE="${SRCROOT}/LowDataHelper/LowDataHelperProtocol.swift"

if [ "$HELPER_SOURCE" -nt "$HELPER_BINARY" ] || [ "$PROTOCOL_SOURCE" -nt "$HELPER_BINARY" ] || [ ! -f "$HELPER_BINARY" ]; then
    echo "Building helper binary..."
    swiftc -o "$HELPER_BINARY" "$HELPER_SOURCE" "$PROTOCOL_SOURCE" \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "${SRCROOT}/LowDataHelper/Info.plist" \
        -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __launchd_plist -Xlinker "${SRCROOT}/LowData/LaunchDaemons/com.lowdata.helper.plist"
    
    # Sign the built binary
    if [ -n "${DEVELOPMENT_TEAM}" ]; then
        echo "Signing built helper with development team: ${DEVELOPMENT_TEAM}"
        codesign --force --deep --sign "Apple Development" --team "${DEVELOPMENT_TEAM}" --identifier "com.lowdata.helper" --options runtime "$HELPER_BINARY"
    fi
fi

# Copy helper binary
cp "${SRCROOT}/LowData/LaunchDaemons/com.lowdata.helper.xpc" "${APP_BUNDLE}/Contents/Library/LaunchDaemons/"

# Copy plist files
cp "${SRCROOT}/LowData/LaunchDaemons/com.lowdata.helper.plist" "${APP_BUNDLE}/Contents/Library/LaunchDaemons/"
# Also copy without extension for SMAppService
cp "${SRCROOT}/LowData/LaunchDaemons/com.lowdata.helper.plist" "${APP_BUNDLE}/Contents/Library/LaunchDaemons/com.lowdata.helper"

# Sign the helper binary if code signing is enabled
if [ -n "$CODE_SIGN_IDENTITY" ]; then
    echo "Signing helper binary..."
    codesign -s "$CODE_SIGN_IDENTITY" --force "${APP_BUNDLE}/Contents/Library/LaunchDaemons/com.lowdata.helper.xpc"
fi

echo "Helper files copied successfully"