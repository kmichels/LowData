import SwiftUI

struct ContentView: View {
    @EnvironmentObject var trafficMonitor: TrafficMonitor
    @EnvironmentObject var networkDetector: NetworkDetector
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(
                networkInfo: networkDetector.networkInfo,
                trafficMonitor: trafficMonitor,
                profileManager: networkDetector.profileManager
            )
            
            Divider()
            
            if trafficMonitor.isMonitoring {
                AppListView(processes: trafficMonitor.processes)
            } else {
                EmptyStateView()
            }
            
            Divider()
            
            FooterView(
                trafficMonitor: trafficMonitor,
                profileManager: networkDetector.profileManager,
                isMonitoring: trafficMonitor.isMonitoring
            )
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct HeaderView: View {
    let networkInfo: NetworkInfo
    @ObservedObject var trafficMonitor: TrafficMonitor
    @ObservedObject var profileManager: NetworkProfileManager
    
    private func formatSessionBits(_ bytes: Int64) -> String {
        if bytes == 0 {
            return "0 bits"
        }
        
        let bits = bytes * 8
        if bits < 1000 {
            return "\(bits) bits"
        } else if bits < 1_000_000 {
            return String(format: "%.1f Kbits", Double(bits) / 1000)
        } else if bits < 1_000_000_000 {
            return String(format: "%.1f Mbits", Double(bits) / 1_000_000)
        } else {
            return String(format: "%.1f Gbits", Double(bits) / 1_000_000_000)
        }
    }
    
    private func formatBitsPerSecond(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond * 8)
        switch bps {
        case 0..<1000:
            return String(format: "%.0f bps", bps)
        case 1000..<1_000_000:
            return String(format: "%.1f Kbps", bps / 1000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1f Mbps", bps / 1_000_000)
        default:
            return String(format: "%.1f Gbps", bps / 1_000_000_000)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Session stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatSessionBits(trafficMonitor.totalSessionBytes))
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Text("This session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if trafficMonitor.sessionStartTime != nil {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if trafficMonitor.isMonitoring {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatBitsPerSecond(trafficMonitor.totalRate))
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        Text("Current rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    trafficMonitor.resetSession()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(!trafficMonitor.isMonitoring)
                .help("Reset session")
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Network info
            HStack {
                Image(systemName: networkInfo.networkType.iconName)
                    .foregroundColor(networkInfo.isConnected ? .blue : .gray)
                
                // Travel Mode indicator
                if profileManager.isTravelMode {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.orange)
                        .font(.footnote)
                        .help("Travel Mode is active - SMB ports are blocked")
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Primary connection display
                    if networkInfo.networkType == .ethernet {
                        Text("Ethernet")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        // If WiFi is also connected, show it as secondary
                        if let ssid = networkInfo.ssid {
                            HStack(spacing: 4) {
                                Text("WiFi: \(ssid)")
                                if let standard = networkInfo.wifiStandard {
                                    Text("(\(standard))")
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    } else if let ssid = networkInfo.ssid, !ssid.isEmpty {
                        // WiFi is primary
                        Text(ssid)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack(spacing: 4) {
                            Text(networkInfo.networkType.rawValue)
                            if let standard = networkInfo.wifiStandard {
                                Text("(\(standard))")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    } else {
                        // Fallback for other connection types
                        Text(networkInfo.networkType.rawValue)
                            .font(.subheadline)
                    }
                }
                
                if let ipv4 = networkInfo.ipAddress {
                    Text("•")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ipv4)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let ipv6 = networkInfo.ipv6Address {
                            Text(ipv6)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct AppListView: View {
    let processes: [ProcessTraffic]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                    AppRowView(process: process, rank: index + 1, isTopConsumer: index < 3)
                    if process.id != processes.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }
}

struct AppRowView: View {
    let process: ProcessTraffic
    let rank: Int
    let isTopConsumer: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank indicator for top consumers
            if isTopConsumer {
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(rank == 1 ? Color.red : 
                                  rank == 2 ? Color.orange : 
                                  Color.yellow)
                    )
            } else {
                Color.clear
                    .frame(width: 20, height: 20)
            }
            
            // App icon
            if let icon = process.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.dashed")
                    .font(.title2)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }
            
            // App name and stats
            VStack(alignment: .leading, spacing: 4) {
                Text(process.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    // Session total
                    Text(process.formattedSessionTotal)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                    
                    // Current rate
                    if process.totalRate > 0 {
                        Label(process.formattedRate, systemImage: "arrow.up.arrow.down.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // Future: Toggle for blocking
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .padding(.trailing, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "network")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Network Monitor")
                .font(.title2)
            
            Text("Click Start to begin monitoring network traffic")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FooterView: View {
    @ObservedObject var trafficMonitor: TrafficMonitor
    @ObservedObject var profileManager: NetworkProfileManager
    let isMonitoring: Bool
    @Environment(\.openSettings) private var openSettings
    @AppStorage("runInMenuBar") private var runInMenuBar = false
    
    var body: some View {
        HStack {
            // Settings button
            Button(action: {
                // Check if we're in a popover (menubar mode)
                if let window = NSApp.windows.first(where: { $0.className.contains("NSPopoverWindow") }),
                   window.isVisible {
                    // We're in a popover, show a tooltip instead
                    print("Right-click the menubar icon for preferences")
                } else {
                    // Normal window mode
                    if #available(macOS 14, *) {
                        openSettings()
                    } else {
                        // For older macOS versions, trigger the menu item
                        if let appMenu = NSApp.mainMenu?.items.first?.submenu {
                            for item in appMenu.items {
                                if item.title.contains("Settings") || item.title.contains("Preferences") {
                                    NSApp.sendAction(item.action!, to: item.target, from: nil)
                                    break
                                }
                            }
                        }
                    }
                }
            }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.plain)
            .help("Preferences")
            
            // Mode toggle button
            Button(action: {
                // Check if we're in a popover
                let inPopover = NSApp.windows.contains { $0.className.contains("NSPopoverWindow") && $0.isVisible }
                
                if inPopover && runInMenuBar {
                    // We're in menubar mode popover, close it before switching
                    for window in NSApp.windows {
                        if window.className.contains("NSPopoverWindow") {
                            window.close()
                        }
                    }
                }
                
                // Toggle the mode - this will trigger onChange in LowDataApp
                runInMenuBar.toggle()
            }) {
                Image(systemName: runInMenuBar ? "menubar.dock.rectangle" : "menubar.rectangle")
            }
            .buttonStyle(.plain)
            .help(runInMenuBar ? "Switch to Dock mode" : "Switch to Menu Bar mode")
            
            // Travel Mode toggle
            Divider()
                .frame(height: 20)
            
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(profileManager.isTravelMode ? .orange : .secondary)
                    .font(.system(size: 12))
                
                Text("Travel Mode")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Toggle("", isOn: Binding(
                    get: { profileManager.isTravelMode },
                    set: { _ in profileManager.toggleTravelMode() }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .labelsHidden()
            }
            .help(profileManager.isTravelMode ? "Travel Mode is ON - SMB ports are blocked" : "Travel Mode is OFF - Normal network access")
            
            if let error = trafficMonitor.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                if isMonitoring {
                    trafficMonitor.stopMonitoring()
                } else {
                    trafficMonitor.startMonitoring()
                }
            }) {
                Label(
                    isMonitoring ? "Stop" : "Start",
                    systemImage: isMonitoring ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(TrafficMonitor())
        .environmentObject(NetworkDetector())
}