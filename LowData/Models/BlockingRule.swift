import Foundation

// MARK: - Blocking Rule Types

enum BlockingRuleType: Codable, Equatable {
    case port(number: Int, protocol: PortProtocol)
    case portRange(start: Int, end: Int, protocol: PortProtocol)
    case service(name: String, ports: [PortRule])
    case application(bundleId: String, name: String)
    
    var displayName: String {
        switch self {
        case .port(let number, let proto):
            return "Port \(number) (\(proto.rawValue.uppercased()))"
        case .portRange(let start, let end, let proto):
            return "Ports \(start)-\(end) (\(proto.rawValue.uppercased()))"
        case .service(let name, _):
            return name
        case .application(_, let name):
            return name
        }
    }
    
    var icon: String {
        switch self {
        case .port, .portRange:
            return "network"
        case .service:
            return "server.rack"
        case .application:
            return "app"
        }
    }
}

enum PortProtocol: String, Codable {
    case tcp = "tcp"
    case udp = "udp"
    case both = "both"
}

struct PortRule: Codable, Equatable {
    let port: Int
    let `protocol`: PortProtocol
}

// MARK: - Blocking Rule Model

struct BlockingRule: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var type: BlockingRuleType
    var isEnabled: Bool
    var isUserAdded: Bool
    var description: String
    var dateAdded: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        type: BlockingRuleType,
        isEnabled: Bool = false,
        isUserAdded: Bool = false,
        description: String = "",
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isEnabled = isEnabled
        self.isUserAdded = isUserAdded
        self.description = description
        self.dateAdded = dateAdded
    }
}

// MARK: - Default Rules

extension BlockingRule {
    static let defaultRules: [BlockingRule] = [
        // SMB File Sharing
        BlockingRule(
            name: "SMB File Sharing",
            type: .service(
                name: "SMB",
                ports: [
                    PortRule(port: 445, protocol: .tcp),
                    PortRule(port: 139, protocol: .tcp),
                    PortRule(port: 137, protocol: .udp),
                    PortRule(port: 138, protocol: .udp)
                ]
            ),
            isEnabled: false,
            isUserAdded: false,
            description: "Windows file sharing and network browsing"
        ),
        
        // AFP File Sharing
        BlockingRule(
            name: "AFP File Sharing",
            type: .service(
                name: "AFP",
                ports: [
                    PortRule(port: 548, protocol: .tcp)
                ]
            ),
            isEnabled: false,
            isUserAdded: false,
            description: "Apple Filing Protocol for Mac file sharing"
        ),
        
        // Screen Sharing / VNC
        BlockingRule(
            name: "Screen Sharing",
            type: .service(
                name: "VNC",
                ports: [
                    PortRule(port: 5900, protocol: .tcp)
                ]
            ),
            isEnabled: false,
            isUserAdded: false,
            description: "Remote desktop and screen sharing"
        ),
        
        // FTP
        BlockingRule(
            name: "FTP",
            type: .service(
                name: "FTP",
                ports: [
                    PortRule(port: 20, protocol: .tcp),
                    PortRule(port: 21, protocol: .tcp)
                ]
            ),
            isEnabled: false,
            isUserAdded: false,
            description: "File Transfer Protocol"
        ),
        
        // Telnet
        BlockingRule(
            name: "Telnet",
            type: .service(
                name: "Telnet",
                ports: [
                    PortRule(port: 23, protocol: .tcp)
                ]
            ),
            isEnabled: false,
            isUserAdded: false,
            description: "Unencrypted remote shell access"
        )
    ]
}