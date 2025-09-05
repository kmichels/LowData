#!/bin/bash

echo "=== Final Helper Fix ==="
echo
echo "This will completely remove and reinstall the helper"
echo

# Kill the helper
echo "1. Killing helper process..."
sudo pkill -9 -f "com.lowdata.helper"

# Remove ALL traces
echo "2. Removing all helper traces..."
sudo launchctl bootout system/com.lowdata.helper 2>/dev/null
sudo rm -rf /Library/LaunchDaemons/com.lowdata.* 2>/dev/null
sudo rm -rf /Library/PrivilegedHelperTools/com.lowdata.* 2>/dev/null
sudo rm -rf ~/Library/LaunchAgents/com.lowdata.* 2>/dev/null
sudo rm -f /tmp/lowdata_rules.conf 2>/dev/null

# Clear caches
echo "3. Clearing all caches..."
sudo sfltool resetbtm 2>/dev/null
sudo dscacheutil -flushcache 2>/dev/null

# Find and remove any other instances
echo "4. Looking for other helper instances..."
sudo find /private/var -name "*lowdata.helper*" -exec rm -rf {} \; 2>/dev/null
sudo find ~/Library -name "*lowdata.helper*" -not -path "*/DerivedData/*" -not -path "*/Developer/LowData/*" -exec rm -rf {} \; 2>/dev/null

echo
echo "5. All helper instances removed."
echo
echo "Now open the app and install helper version 2.0.3"
echo "It should show debug messages in Console about using anchors."