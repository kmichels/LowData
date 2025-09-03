#!/bin/bash

# Build and sign the privileged helper tool
# This script compiles and signs the helper tool for SMJobBless

set -e

# Configuration
HELPER_NAME="com.lowdata.helper"
HELPER_SOURCE="LowDataHelper/main.swift"
BUILD_DIR="build"
DEVELOPER_ID="Developer ID Application: Konrad Michels (85QL287QYW)"

echo "Building LowData Privileged Helper Tool..."

# Create build directory
mkdir -p "$BUILD_DIR"

# Compile the helper tool
echo "Compiling helper..."
swiftc "$HELPER_SOURCE" \
    -o "$BUILD_DIR/$HELPER_NAME" \
    -O \
    -whole-module-optimization

# Copy Info.plist to build directory
cp "LowDataHelper/Info.plist" "$BUILD_DIR/Info.plist"

# Sign the helper tool
echo "Signing helper with Developer ID..."
codesign --force \
    --sign "$DEVELOPER_ID" \
    --identifier "$HELPER_NAME" \
    --options runtime \
    --timestamp \
    "$BUILD_DIR/$HELPER_NAME"

# Verify signature
echo "Verifying signature..."
codesign -dvvv "$BUILD_DIR/$HELPER_NAME"

# Create the helper bundle structure for embedding in app
HELPER_BUNDLE="$BUILD_DIR/${HELPER_NAME}.bundle"
mkdir -p "$HELPER_BUNDLE/Contents/MacOS"
mkdir -p "$HELPER_BUNDLE/Contents/Resources"

# Copy files to bundle
cp "$BUILD_DIR/$HELPER_NAME" "$HELPER_BUNDLE/Contents/MacOS/"
cp "LowDataHelper/Info.plist" "$HELPER_BUNDLE/Contents/"
cp "LowDataHelper/com.lowdata.helper.plist" "$HELPER_BUNDLE/Contents/Resources/"

echo ""
echo "Helper tool built successfully!"
echo "Location: $BUILD_DIR/$HELPER_NAME"
echo ""
echo "To embed in Xcode project:"
echo "1. Add $HELPER_BUNDLE to your Xcode project"
echo "2. Add to 'Copy Bundle Resources' build phase"
echo "3. The app will install it to /Library/PrivilegedHelperTools/ when needed"