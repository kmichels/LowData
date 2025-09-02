# Low Data Implementation Plan

## Overview
Simplified network monitoring app using system commands (nettop/lsof) instead of Network Extensions.

## Phase 1: Project Cleanup

### Files to Delete
```bash
# Remove Network Extension components
rm -rf LowDataExtension/
rm LowData/ExtensionManager.swift
rm LowData/SharedConstants.swift
rm LowData/Persistence.swift

# Remove test folders (rebuild later if needed)
rm -rf LowDataTests/
rm -rf LowDataUITests/
```

### Files to Keep
- `LowData/LowDataApp.swift` - Main app entry point
- `LowData/ContentView.swift` - Will be rewritten
- `LowData/LowData.entitlements` - Remove Network Extension capabilities
- `LowData/Info.plist` - Add NSAppleEventsUsageDescription

### Xcode Project Updates
1. Remove LowDataExtension target
2. Remove Network Extension capability
3. Remove App Groups capability
4. Clean up build phases and dependencies

## Phase 2: Create New Structure

### Directory Layout
```
LowData/
├── Models/
│   ├── ProcessTraffic.swift
│   └── NetworkInfo.swift
├── Services/
│   ├── CommandRunner.swift
│   ├── TrafficMonitor.swift
│   └── NetworkDetector.swift
├── Views/
│   └── ContentView.swift
├── LowDataApp.swift
├── Info.plist
└── LowData.entitlements
```

## Phase 3: Implementation Order

### Step 1: Core Infrastructure (Day 1)
1. **CommandRunner.swift**
   - Generic service to execute shell commands
   - Uses Process() class
   - Returns command output as String
   - Error handling for failed commands

2. **Data Models**
   - ProcessTraffic: Stores per-process network usage
   - NetworkInfo: Current network connection details

### Step 2: Monitoring Services (Day 1-2)
1. **TrafficMonitor.swift**
   - Primary: Parse `nettop -P -L 1 -J bytes_in,bytes_out`
   - Fallback: Parse `lsof -i -n -P` for connection counts
   - Timer-based updates (1-2 second intervals)
   - @Published array of ProcessTraffic objects

2. **NetworkDetector.swift**
   - CoreWLAN for WiFi SSID detection
   - Network.framework for connection type
   - NWPathMonitor for network changes
   - @Published NetworkInfo object

### Step 3: User Interface (Day 2)
1. **ContentView.swift**
   - Header: Current network info (SSID, type, IP)
   - Main area: Process list sorted by bandwidth
   - Each row: Process name, PID, bytes in/out, connections
   - Footer: Total bandwidth stats
   - Control: Start/Stop monitoring button

### Step 4: Polish & Testing (Day 3)
1. **Info.plist Configuration**
   - Add NSAppleEventsUsageDescription
   - Update bundle identifier if needed

2. **Error Handling**
   - Graceful fallback when nettop fails
   - Handle missing permissions
   - User-friendly error messages

3. **Performance**
   - Efficient parsing of command output
   - Minimize UI updates
   - Memory management for long-running sessions

## Technical Details

### nettop Command Parsing
```bash
nettop -P -L 1 -J bytes_in,bytes_out
```
Output format (CSV):
```
time,process,pid,bytes_in,bytes_out
1234567890,Safari,1234,1000000,500000
```

### lsof Command Parsing (Fallback)
```bash
lsof -i -n -P
```
Output format:
```
COMMAND   PID USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
Safari    1234 user   5u  IPv4  0x123    0t0  TCP 192.168.1.2:51234->1.2.3.4:443 (ESTABLISHED)
```

### Key SwiftUI Patterns
- ObservableObject for services
- @StateObject in main view
- @Published for reactive updates
- Timer.publish for periodic updates

## Testing Strategy

### Manual Testing
1. Run from Xcode (no provisioning needed)
2. Verify process list updates
3. Test network detection (switch WiFi networks)
4. Verify bandwidth calculations
5. Test start/stop functionality

### Edge Cases
- No network connection
- VPN connections
- Multiple network interfaces
- High process count
- Permission denied scenarios

## Success Criteria

### Phase 1 Complete When:
- [x] Shows real-time process network usage
- [x] Detects current network (SSID/type)
- [x] Updates every 1-2 seconds
- [x] Handles errors gracefully
- [x] Start/stop monitoring works
- [x] No special entitlements required
- [x] Runs directly from Xcode

## Future Enhancements (Phase 2)

### Network Blocking
- Privileged helper tool using SMJobBless
- pfctl integration for firewall rules
- Per-process blocking UI
- Requires admin authentication

### Additional Features
- Historical bandwidth graphs
- Network profiles (home/work/public)
- Export statistics
- Menu bar widget
- Notifications for high usage

## Commands Reference

### Get Network Interface
```bash
route get default | grep interface | awk '{print $2}'
```

### Get WiFi SSID (via CoreWLAN)
```swift
CWWiFiClient.shared().interface()?.ssid()
```

### Monitor Traffic
```bash
# Real-time bandwidth
nettop -P -L 1 -J bytes_in,bytes_out

# Connection list
lsof -i -n -P

# Network interfaces
ifconfig -a
```

## Libraries/Frameworks Used
- SwiftUI (UI)
- Foundation (Process execution)
- CoreWLAN (WiFi detection)
- Network.framework (Connection monitoring)
- SystemConfiguration (Network info)

## No External Dependencies
- No CocoaPods
- No Swift Package Manager packages
- Built-in frameworks only
- Pure Swift/SwiftUI implementation