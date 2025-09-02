# CLAUDE.md - Low Data: Simple Network Monitor

## Project Overview
Build a network traffic monitoring app for macOS using built-in system tools (nettop/lsof). No Network Extensions, no special entitlements, no provisioning hell. Just a working app that shows network usage per application.

## Current Situation
- Abandoned Network Extension approach (too complex)
- Have basic SwiftUI project created
- Using system commands for monitoring
- Phase 1: Monitor only (no blocking)
- Phase 2: Add blocking via pfctl (later)

## Architecture
```
Low Data.app
├── Traffic Monitor Service
│   ├── Runs nettop/lsof commands via Process()
│   ├── Parses output into ProcessTraffic models
│   └── Updates every 1-2 seconds
├── Network Detection
│   ├── Uses CoreWLAN for WiFi SSID
│   ├── Uses Network.framework for connection type
│   └── Identifies current network context
└── SwiftUI Interface
    ├── Process list sorted by bandwidth
    ├── Real-time statistics
    └── Start/stop monitoring controls
```

## Implementation Approach

### Core Components

1. **CommandRunner Service**
   - Executes shell commands using Process()
   - Returns parsed output as strings
   - Handles errors gracefully

2. **TrafficMonitor Service (ObservableObject)**
   - Primary: Parse nettop output for bandwidth data
   - Fallback: Use lsof for connection counts
   - Updates @Published properties for UI binding
   - Runs on timer/async loop

3. **NetworkDetector Service (ObservableObject)**
   - Detects WiFi SSID using CoreWLAN
   - Identifies network type (WiFi/Ethernet/Cellular)
   - Gets current IP address
   - Uses NWPathMonitor for changes

4. **Data Models**
   - ProcessTraffic: name, pid, bytesIn, bytesOut, connections
   - NetworkInfo: interface, ssid, ipAddress, type

5. **UI Structure**
   - Main list showing processes sorted by bandwidth
   - Header showing current network
   - Stats panel with totals
   - Start/Stop button

### Commands to Use

**Primary monitoring:**
```bash
nettop -P -L 1 -J bytes_in,bytes_out
# Returns CSV with process,pid,bytes_in,bytes_out
```

**Fallback monitoring:**
```bash
lsof -i -n -P
# Returns list of network connections per process
```

**Network detection:**
- CoreWLAN framework for WiFi SSID
- Network.framework for connection type
- SystemConfiguration for IP addresses

### File Structure
```
LowData/
├── Models/
│   ├── ProcessTraffic.swift
│   └── NetworkInfo.swift
├── Services/
│   ├── TrafficMonitor.swift
│   ├── CommandRunner.swift
│   └── NetworkDetector.swift
├── Views/
│   └── ContentView.swift
└── Info.plist (needs NSAppleEventsUsageDescription)
```

### Info.plist Requirements
Add permission to run Apple Events:
- Key: `NSAppleEventsUsageDescription`
- Value: "Low Data needs to run system commands to monitor network usage."

### Key Implementation Notes

1. **No special entitlements needed** - runs in user space
2. **Use Process() class** to execute shell commands
3. **Parse text output** from commands into Swift models
4. **Update UI via @Published** properties and ObservableObject
5. **Handle command failures** gracefully with fallbacks
6. **No admin privileges** required for monitoring phase

### Phase 1 Goals (Monitoring Only)
- Show list of processes using network
- Display bandwidth per process (if available from nettop)
- Show connection count per process (from lsof)
- Detect current network (SSID, type)
- Update in real-time (1-2 second intervals)
- Start/stop monitoring on demand

### Phase 2 (Future - Blocking)
- Will require privileged helper tool
- Use pfctl to create firewall rules
- SMJobBless for helper installation
- Admin password required once

### Testing
- Run directly from Xcode
- No provisioning profiles needed
- No certificates required
- Just build and run

### Common Issues
- **nettop fails**: Fall back to lsof (less data but works)
- **Permission denied**: Check Info.plist has Apple Events permission
- **No data**: Some processes may not show without admin rights
- **WiFi SSID missing**: CoreWLAN might need location permission
