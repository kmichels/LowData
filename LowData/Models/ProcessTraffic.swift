import Foundation
import AppKit

struct ProcessTraffic: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let pid: Int
    var bytesIn: Int64
    var bytesOut: Int64
    var sessionBytesIn: Int64 = 0
    var sessionBytesOut: Int64 = 0
    var bytesInRate: Int64 = 0  // bytes per second
    var bytesOutRate: Int64 = 0  // bytes per second
    var connectionsCount: Int
    let timestamp: Date
    var appPath: String?
    var isApp: Bool = false
    
    var totalBytes: Int64 {
        bytesIn + bytesOut
    }
    
    var sessionTotalBytes: Int64 {
        sessionBytesIn + sessionBytesOut
    }
    
    var totalRate: Int64 {
        bytesInRate + bytesOutRate
    }
    
    var formattedSessionTotal: String {
        // Show in bits for consistency
        if sessionTotalBytes == 0 {
            return "0 bits"
        }
        
        let bits = sessionTotalBytes * 8
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
    
    var formattedRate: String {
        formatBitsPerSecond(totalRate * 8)  // Convert bytes to bits
    }
    
    var appIcon: NSImage? {
        guard let appPath = appPath else { return nil }
        return NSWorkspace.shared.icon(forFile: appPath)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatBitsPerSecond(_ bitsPerSecond: Int64) -> String {
        let bps = Double(bitsPerSecond)
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
    
    static func == (lhs: ProcessTraffic, rhs: ProcessTraffic) -> Bool {
        lhs.pid == rhs.pid && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
        hasher.combine(name)
    }
}