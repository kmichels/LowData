#!/bin/bash

echo "=== Checking Helper Installation ==="
echo

echo "1. Helper in app bundle:"
if [ -f "/Users/konrad/Library/Developer/Xcode/DerivedData/LowData-fcsvoirhsbahzsgeamnefpgcsywm/Build/Products/Debug/LowData.app/Contents/Library/LaunchDaemons/com.lowdata.helper.xpc" ]; then
    echo "   Found - checking for anchor code:"
    strings "/Users/konrad/Library/Developer/Xcode/DerivedData/LowData-fcsvoirhsbahzsgeamnefpgcsywm/Build/Products/Debug/LowData.app/Contents/Library/LaunchDaemons/com.lowdata.helper.xpc" | grep -q "\-a.*anchorName"
    if [ $? -eq 0 ]; then
        echo "   ✅ Has anchor fix"
    else
        echo "   ❌ Missing anchor fix"
    fi
    strings "/Users/konrad/Library/Developer/Xcode/DerivedData/LowData-fcsvoirhsbahzsgeamnefpgcsywm/Build/Products/Debug/LowData.app/Contents/Library/LaunchDaemons/com.lowdata.helper.xpc" | grep "Version.*2\.0"
else
    echo "   Not found"
fi

echo
echo "2. Helper in source directory:"
if [ -f "/Users/konrad/Developer/LowData/LowData/LaunchDaemons/com.lowdata.helper.xpc" ]; then
    echo "   Found - checking for anchor code:"
    strings "/Users/konrad/Developer/LowData/LowData/LaunchDaemons/com.lowdata.helper.xpc" | grep -q "\-a.*anchorName"
    if [ $? -eq 0 ]; then
        echo "   ✅ Has anchor fix"
    else
        echo "   ❌ Missing anchor fix"  
    fi
    strings "/Users/konrad/Developer/LowData/LowData/LaunchDaemons/com.lowdata.helper.xpc" | grep "Version.*2\.0"
else
    echo "   Not found"
fi

echo
echo "3. Process running:"
ps aux | grep -i "lowdata.helper" | grep -v grep || echo "   No helper process running"

echo
echo "4. Looking for any other helper installations:"
find /Library -name "*lowdata.helper*" 2>/dev/null
find ~/Library -name "*lowdata.helper*" -path "*/DerivedData/*" -prune -o -print 2>/dev/null | grep -v DerivedData

echo
echo "5. Checking launchd (requires sudo):"
echo "   Run: sudo launchctl print system/com.lowdata.helper"