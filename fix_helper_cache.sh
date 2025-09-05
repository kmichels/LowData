#!/bin/bash

echo "=== Fix Helper Cache Script ==="
echo "This script will clear the SMAppService cache and force a fresh helper installation"
echo

# Step 1: Kill any running helper
echo "Step 1: Killing any running helper processes..."
sudo pkill -f "com.lowdata.helper" 2>/dev/null

# Step 2: Remove the helper from launchd
echo "Step 2: Unloading helper from launchd..."
sudo launchctl bootout system/com.lowdata.helper 2>/dev/null

# Step 3: Reset background task management cache
echo "Step 3: Resetting background task management cache..."
sudo sfltool resetbtm 2>/dev/null

# Step 4: Clear LaunchServices cache
echo "Step 4: Clearing LaunchServices cache..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

# Step 5: Remove any cached helper files
echo "Step 5: Removing any cached helper files..."
sudo rm -rf ~/Library/LaunchAgents/com.lowdata.helper* 2>/dev/null
sudo rm -rf /Library/LaunchDaemons/com.lowdata.helper* 2>/dev/null
sudo rm -rf /Library/PrivilegedHelperTools/com.lowdata.helper* 2>/dev/null

# Step 6: Clear temporary files
echo "Step 6: Clearing temporary files..."
sudo rm -f /tmp/lowdata_rules.conf 2>/dev/null

echo
echo "Cache clearing complete!"
echo
echo "Now:"
echo "1. Open the LowData app"
echo "2. Go to Preferences > Blocking Rules"
echo "3. Click 'Install Helper' to install the fresh version"
echo "4. The app should now use the updated helper with all fixes"