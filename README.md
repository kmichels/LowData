# LowData - Network Monitor & Firewall for macOS

A native macOS application that monitors network traffic and provides per-application firewall controls. Built for macOS 15 (Sequoia) and later.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Network Monitoring
- **Real-time traffic monitoring** - See which applications are using your network
- **Bandwidth tracking** - Monitor upload/download speeds per application
- **Connection counting** - Track number of active connections per process
- **Network detection** - Automatically detect WiFi SSID and network type
- **History tracking** - View network usage patterns over time

### Firewall Controls (Privileged Helper Required)
- **Per-application blocking** - Block network access for specific applications
- **Port-based rules** - Control access to specific ports and protocols
- **Service presets** - Quick rules for common services (SSH, Screen Sharing, etc.)
- **Network-aware rules** - Different rules for different networks (home, work, public)

## Installation

### Requirements
- macOS 15.0 (Sequoia) or later
- Xcode 16.0 or later (for building from source)

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/kmichels/LowData.git
cd LowData
```

2. Open in Xcode:
```bash
open LowData.xcodeproj
```

3. Build and run (⌘R)

### Installing the Privileged Helper

For firewall functionality, you'll need to install the privileged helper:

1. Open LowData preferences (⌘,)
2. Click "Install Helper" in the Blocking Rules section
3. Enter your admin password when prompted
4. The helper will be installed and registered with the system

## Usage

### Basic Monitoring
The app starts monitoring automatically when launched. You can see:
- Active processes using network
- Current bandwidth usage
- Total data transferred
- Network connection details

### Creating Firewall Rules
1. Go to Settings → Blocking Rules
2. Click "+" to add a new rule
3. Choose rule type:
   - **Application** - Block a specific app
   - **Port** - Block a specific port
   - **Port Range** - Block a range of ports
   - **Service** - Block common services

4. Enable/disable rules with the toggle switch
5. Rules take effect immediately when the helper is installed

## Architecture Overview

LowData uses a modern architecture that avoids the complexity of Network Extensions:

```
┌─────────────────────────────────────────┐
│         LowData.app (SwiftUI)          │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │   Network     │  │    Firewall     │ │
│  │   Monitor     │  │    Manager      │ │
│  └──────┬───────┘  └────────┬────────┘ │
│         │                    │          │
│         ▼                    ▼          │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │   nettop/    │  │       XPC       │ │
│  │    lsof      │  │   Connection    │ │
│  └──────────────┘  └────────┬────────┘ │
└─────────────────────────────┼──────────┘
                              │
                              ▼
                 ┌─────────────────────────┐
                 │   Privileged Helper      │
                 │  (com.lowdata.helper)    │
                 │                          │
                 │   Manages pfctl rules    │
                 │   Runs as root daemon    │
                 └──────────────────────────┘
```

### Key Components

- **Main App** - SwiftUI interface, network monitoring, user preferences
- **Network Monitor** - Uses `nettop` and `lsof` commands for traffic data
- **Privileged Helper** - Root daemon that manages firewall rules via `pfctl`
- **XPC Communication** - Secure communication between app and helper

### Security Model

- Main app runs in user space with standard permissions
- Network monitoring uses built-in system commands (no special entitlements)
- Firewall control requires privileged helper (one-time admin authorization)
- Helper installed via SMAppService API (modern macOS 13+ approach)
- All components are signed with Developer ID

## Technical Notes

### SMAppService Migration
This project uses the modern SMAppService API introduced in macOS 13, replacing the deprecated SMJobBless. For detailed information about the migration and troubleshooting, see [HELPER_TROUBLESHOOTING.md](HELPER_TROUBLESHOOTING.md).

### Key Technologies
- **SwiftUI** - Native macOS user interface
- **Combine** - Reactive data flow and state management
- **ServiceManagement** - Privileged helper installation (SMAppService)
- **XPC** - Inter-process communication with helper daemon
- **pfctl** - BSD packet filter for firewall rules

### Development Considerations

#### Network Monitoring
- Uses `nettop -P -L 1 -J bytes_in,bytes_out` for bandwidth data
- Falls back to `lsof -i -n -P` for connection information
- Polling interval: 1-2 seconds for real-time updates
- No root privileges required for monitoring

#### Firewall Implementation
- Helper daemon runs as LaunchDaemon (root privileges)
- Uses `pfctl` with custom anchor for rule management
- Rules are applied immediately without system restart
- Rules persist across app restarts (stored in UserDefaults)

## Troubleshooting

### App Won't Start
- Ensure you're running macOS 15.0 or later
- Check Console.app for crash logs
- Try deleting ~/Library/Preferences/com.tonalphoto.tech.LowData.plist

### Helper Installation Fails
- Make sure you have admin privileges
- Check System Settings → General → Login Items for blocked items
- See [HELPER_TROUBLESHOOTING.md](HELPER_TROUBLESHOOTING.md) for detailed debugging

### No Network Data Showing
- Grant necessary permissions when prompted
- Some processes may not show data without the helper installed
- Check if `nettop` command works in Terminal

### Firewall Rules Not Working
- Verify helper is installed (check Settings → Blocking Rules)
- Ensure the helper shows "Running" status
- Check Console.app for helper daemon logs
- Try uninstalling and reinstalling the helper

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure the app builds without warnings
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with insights from the macOS developer community
- SMAppService implementation guided by various GitHub examples
- Special thanks to developers who documented SMAppService quirks

## Resources

- [HELPER_TROUBLESHOOTING.md](HELPER_TROUBLESHOOTING.md) - Detailed helper installation debugging
- [Apple's ServiceManagement Documentation](https://developer.apple.com/documentation/servicemanagement)
- [pfctl Manual Page](https://www.freebsd.org/cgi/man.cgi?query=pfctl)

---

**Note:** This app requires macOS 15 (Sequoia) or later and will not work on earlier versions of macOS. The privileged helper installation requires administrator privileges but only needs to be done once.