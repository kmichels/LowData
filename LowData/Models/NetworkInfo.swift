import Foundation

struct NetworkInfo {
    let interface: String
    let ssid: String?
    let ipAddress: String?      // IPv4 address
    let ipv6Address: String?    // IPv6 address
    let networkType: NetworkType
    let isConnected: Bool
    let wifiStandard: String?  // e.g., "Wi-Fi 6", "Wi-Fi 5"
    
    enum NetworkType: String, CaseIterable {
        case wifi = "Wi-Fi"
        case ethernet = "Ethernet"
        case cellular = "Cellular"
        case unknown = "Unknown"
        
        var iconName: String {
            switch self {
            case .wifi:
                return "wifi"
            case .ethernet:
                return "cable.connector"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .unknown:
                return "network"
            }
        }
    }
    
    var displayName: String {
        if let ssid = ssid, !ssid.isEmpty {
            return "\(ssid) (\(networkType.rawValue))"
        } else {
            return networkType.rawValue
        }
    }
    
    static var disconnected: NetworkInfo {
        NetworkInfo(
            interface: "",
            ssid: nil,
            ipAddress: nil,
            ipv6Address: nil,
            networkType: .unknown,
            isConnected: false,
            wifiStandard: nil
        )
    }
}