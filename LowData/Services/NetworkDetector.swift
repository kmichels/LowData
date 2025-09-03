import Foundation
import Network
import CoreWLAN
import SystemConfiguration

@MainActor
class NetworkDetector: ObservableObject {
    @Published var networkInfo: NetworkInfo = .disconnected
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let wifiClient = CWWiFiClient.shared()
    
    init() {
        startMonitoring()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                await self?.updateNetworkInfo(path: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func updateNetworkInfo(path: NWPath) async {
        guard path.status == .satisfied else {
            networkInfo = .disconnected
            return
        }
        
        let networkType = detectNetworkType(path: path)
        let interface = getActiveInterface()
        
        // Check if both Ethernet and WiFi are connected
        let hasEthernet = path.usesInterfaceType(.wiredEthernet)
        let hasWifi = path.usesInterfaceType(.wifi)
        
        // Get WiFi info even if Ethernet is primary (for display purposes)
        let ssid = (hasWifi) ? getWiFiSSID() : nil
        let wifiStandard = (hasWifi) ? getWiFiStandard() : nil
        
        let (ipv4, ipv6) = getIPAddresses(for: interface)
        
        // If both connections exist, we might want to indicate this
        let displayType = networkType
        if hasEthernet && hasWifi && ssid != nil {
            // We're using Ethernet but WiFi is also connected
            // Keep networkType as ethernet but we'll show WiFi info too
        }
        
        networkInfo = NetworkInfo(
            interface: interface ?? "Unknown",
            ssid: ssid,
            ipAddress: ipv4,
            ipv6Address: ipv6,
            networkType: displayType,
            isConnected: true,
            wifiStandard: wifiStandard
        )
    }
    
    private func detectNetworkType(path: NWPath) -> NetworkInfo.NetworkType {
        // Check what interfaces are being used
        // Note: Both can be true if using both connections
        let usesWifi = path.usesInterfaceType(.wifi)
        let usesEthernet = path.usesInterfaceType(.wiredEthernet)
        let usesCellular = path.usesInterfaceType(.cellular)
        
        // Priority: Ethernet > WiFi > Cellular
        // This matches how macOS typically prioritizes connections
        if usesEthernet {
            return .ethernet
        } else if usesWifi {
            return .wifi
        } else if usesCellular {
            return .cellular
        } else {
            return .unknown
        }
    }
    
    private func getWiFiSSID() -> String? {
        // Try CoreWLAN first
        if let interface = wifiClient.interface() {
            if let ssid = interface.ssid() {
                return ssid
            }
        }
        
        // Fallback: Try using system_profiler command
        do {
            let output = try CommandRunner.shared.execute("system_profiler SPAirPortDataType").get()
            let lines = output.components(separatedBy: .newlines)
            
            // Look for the line after "Current Network Information:"
            for i in 0..<lines.count {
                if lines[i].contains("Current Network Information:") && i + 1 < lines.count {
                    let nextLine = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    // The SSID is the part before the colon
                    if let colonIndex = nextLine.firstIndex(of: ":") {
                        let ssid = String(nextLine[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        if !ssid.isEmpty && !ssid.contains("Network Type") {
                            return ssid
                        }
                    }
                }
            }
        } catch {
            // Silent fail
        }
        
        return nil
    }
    
    private func getWiFiStandard() -> String? {
        // Try to get from CoreWLAN interface first
        if let interface = wifiClient.interface() {
            let phyMode = interface.activePHYMode()
            switch phyMode {
            case .mode11ax:
                return "Wi-Fi 6"
            case .mode11ac:
                return "Wi-Fi 5"
            case .mode11n:
                return "Wi-Fi 4"
            case .mode11a, .mode11g:
                return "Wi-Fi 3"
            default:
                break
            }
        }
        
        // Fallback: Try to detect WiFi standard using system_profiler
        do {
            let output = try CommandRunner.shared.execute("system_profiler SPAirPortDataType").get()
            
            // Look for PHY Mode in output
            if output.contains("802.11ax") {
                return "Wi-Fi 6"
            } else if output.contains("802.11ac") {
                return "Wi-Fi 5"
            } else if output.contains("802.11n") {
                return "Wi-Fi 4"
            } else if output.contains("802.11a") || output.contains("802.11g") {
                return "Wi-Fi 3"
            }
        } catch {
            // Silent fail
        }
        
        return nil
    }
    
    private func getActiveInterface() -> String? {
        do {
            let output = try CommandRunner.shared.execute("route get default | grep interface | awk '{print $2}'").get()
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
    
    private func getIPAddresses(for interface: String?) -> (ipv4: String?, ipv6: String?) {
        guard let interface = interface else { return (nil, nil) }
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (nil, nil) }
        defer { freeifaddrs(ifaddr) }
        
        var ipv4Address: String?
        var ipv6Address: String?
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            let iface = ptr?.pointee
            let addrFamily = iface?.ifa_addr?.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                let name = String(cString: (iface?.ifa_name)!)
                if name == interface {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(iface?.ifa_addr,
                               socklen_t((iface?.ifa_addr?.pointee.sa_len)!),
                               &hostname,
                               socklen_t(hostname.count),
                               nil,
                               socklen_t(0),
                               NI_NUMERICHOST)
                    
                    let address = String(cString: hostname)
                    
                    if addrFamily == UInt8(AF_INET) && !address.isEmpty {
                        ipv4Address = address
                    } else if addrFamily == UInt8(AF_INET6) && !address.isEmpty {
                        // Filter out link-local IPv6 addresses (fe80::)
                        if !address.hasPrefix("fe80") {
                            ipv6Address = address
                        }
                    }
                }
            }
        }
        
        return (ipv4Address, ipv6Address)
    }
}

extension CommandRunner {
    func execute(_ command: String) -> Result<String, Error> {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if task.terminationStatus != 0 {
                return .failure(CommandError.executionFailed(output))
            }
            
            return .success(output)
        } catch {
            return .failure(error)
        }
    }
}