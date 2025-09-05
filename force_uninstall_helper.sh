#!/bin/bash

echo "Force uninstalling old helper daemon..."

# Kill any running helper process
echo "Killing any running helper processes..."
sudo pkill -f "com.lowdata.helper" 2>/dev/null

# Unload from launchd if loaded
echo "Unloading from launchd..."
sudo launchctl bootout system/com.lowdata.helper 2>/dev/null

# Remove the installed helper binary
echo "Removing installed helper binary..."
sudo rm -f /Library/PrivilegedHelperTools/com.lowdata.helper.xpc 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.lowdata.helper.plist 2>/dev/null

# Clear launchd cache
echo "Clearing launchd cache..."
sudo launchctl kickstart -k system/com.apple.xpc.launchd 2>/dev/null

# Remove any temporary rules files
echo "Removing temporary files..."
sudo rm -f /tmp/lowdata_rules.conf 2>/dev/null

# Check if helper is still registered
echo "Checking launchd status..."
sudo launchctl print system/com.lowdata.helper 2>&1 | head -5

echo "Force uninstall complete. Now reinstall the helper from the app."