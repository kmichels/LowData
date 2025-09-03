import Foundation

// LowData Privileged Helper Tool
// Handles pfctl commands for blocking network traffic

class LowDataHelper: NSObject {
    
    // MARK: - Properties
    private let listener: NSXPCListener
    
    // MARK: - Initialization
    override init() {
        self.listener = NSXPCListener(machServiceName: "com.lowdata.helper")
        super.init()
    }
    
    func run() {
        // Configure listener
        listener.delegate = self
        
        // Start listening
        listener.resume()
        
        // Keep the helper running
        RunLoop.current.run()
    }
}

// MARK: - NSXPCListenerDelegate
extension LowDataHelper: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the connection is from our main app
        guard verifyConnection(newConnection) else {
            NSLog("LowDataHelper: Rejected unauthorized connection")
            return false
        }
        
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: LowDataHelperProtocol.self)
        newConnection.exportedObject = LowDataHelperService()
        
        // Set up invalidation handler
        newConnection.invalidationHandler = {
            NSLog("LowDataHelper: Connection invalidated")
        }
        
        // Set up interruption handler
        newConnection.interruptionHandler = {
            NSLog("LowDataHelper: Connection interrupted")
        }
        
        // Resume the connection
        newConnection.resume()
        
        return true
    }
    
    private func verifyConnection(_ connection: NSXPCConnection) -> Bool {
        // TODO: Implement proper code signing verification
        // For now, accept all connections (DEVELOPMENT ONLY)
        return true
    }
}

// MARK: - Helper Protocol
@objc protocol LowDataHelperProtocol {
    func applyBlockingRules(_ rules: [[String: Any]], reply: @escaping (Bool, String?) -> Void)
    func removeAllBlockingRules(reply: @escaping (Bool, String?) -> Void)
    func getHelperVersion(reply: @escaping (String) -> Void)
}

// MARK: - Helper Service Implementation
class LowDataHelperService: NSObject, LowDataHelperProtocol {
    
    private let helperVersion = "1.0.0"
    private let pfctlPath = "/sbin/pfctl"
    private let rulesFile = "/tmp/lowdata_rules.conf"
    
    func getHelperVersion(reply: @escaping (String) -> Void) {
        reply(helperVersion)
    }
    
    func applyBlockingRules(_ rules: [[String: Any]], reply: @escaping (Bool, String?) -> Void) {
        NSLog("LowDataHelper: Applying \(rules.count) blocking rules")
        
        // Generate pfctl rules
        var pfRules = [String]()
        
        for rule in rules {
            guard let type = rule["type"] as? String else { continue }
            
            switch type {
            case "port":
                if let port = rule["port"] as? Int,
                   let proto = rule["protocol"] as? String {
                    // Block outgoing traffic to this port
                    pfRules.append("block drop out proto \(proto) from any to any port \(port)")
                }
                
            case "service":
                if let ports = rule["ports"] as? [[String: Any]] {
                    for portInfo in ports {
                        if let port = portInfo["port"] as? Int,
                           let proto = portInfo["protocol"] as? String {
                            pfRules.append("block drop out proto \(proto) from any to any port \(port)")
                        }
                    }
                }
                
            case "application":
                // Application blocking is more complex and may require different approach
                // For now, log it
                if let bundleId = rule["bundleId"] as? String {
                    NSLog("LowDataHelper: Would block application: \(bundleId)")
                    // TODO: Implement application-based blocking
                }
                
            default:
                break
            }
        }
        
        // Write rules to file
        let rulesContent = pfRules.joined(separator: "\n")
        
        do {
            try rulesContent.write(toFile: rulesFile, atomically: true, encoding: .utf8)
            
            // Apply rules using pfctl
            let result = runCommand(pfctlPath, arguments: ["-f", rulesFile, "-e"])
            
            if result.0 == 0 {
                NSLog("LowDataHelper: Successfully applied \(pfRules.count) rules")
                reply(true, nil)
            } else {
                let error = "Failed to apply rules: \(result.1)"
                NSLog("LowDataHelper: \(error)")
                reply(false, error)
            }
            
        } catch {
            let errorMsg = "Failed to write rules file: \(error.localizedDescription)"
            NSLog("LowDataHelper: \(errorMsg)")
            reply(false, errorMsg)
        }
    }
    
    func removeAllBlockingRules(reply: @escaping (Bool, String?) -> Void) {
        NSLog("LowDataHelper: Removing all blocking rules")
        
        // Flush pfctl rules
        let result = runCommand(pfctlPath, arguments: ["-F", "rules"])
        
        if result.0 == 0 {
            // Clean up rules file
            try? FileManager.default.removeItem(atPath: rulesFile)
            
            NSLog("LowDataHelper: Successfully removed all rules")
            reply(true, nil)
        } else {
            let error = "Failed to flush rules: \(result.1)"
            NSLog("LowDataHelper: \(error)")
            reply(false, error)
        }
    }
    
    private func runCommand(_ command: String, arguments: [String]) -> (Int32, String) {
        let task = Process()
        task.launchPath = command
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return (task.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
    }
}

// MARK: - Main Entry Point
let helper = LowDataHelper()
helper.run()