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
                // Application blocking - use a combination of approaches
                if let bundleId = rule["bundleId"] as? String {
                    NSLog("LowDataHelper: Blocking application: \(bundleId)")
                    
                    // Add comment for clarity
                    pfRules.append("# Block application: \(bundleId)")
                    
                    // Method 1: Block by known ports if available
                    if let appPorts = rule["ports"] as? [[String: Any]] {
                        for portInfo in appPorts {
                            if let port = portInfo["port"] as? Int,
                               let proto = portInfo["protocol"] as? String {
                                pfRules.append("block drop out proto \(proto) from any to any port \(port)")
                            }
                        }
                    }
                    
                    // Method 2: Block by process owner (if we can determine it)
                    // This is more reliable than PID-based blocking
                    if let appPath = getApplicationPath(for: bundleId),
                       let executable = getExecutableName(from: appPath) {
                        // Create a table to track this app's connections
                        let tableName = bundleId.replacingOccurrences(of: ".", with: "_")
                        pfRules.append("table <\(tableName)_blocked> persist")
                        
                        // Note: Full application blocking would require kernel extension
                        // For now, we'll document the limitation
                        pfRules.append("# Note: Full app blocking requires Network Extension")
                    }
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
    
    private func getApplicationPath(for bundleId: String) -> String? {
        // Use LSCopyApplicationURLsForBundleIdentifier or mdfind to locate app
        let result = runCommand("/usr/bin/mdfind", arguments: ["kMDItemCFBundleIdentifier == '\(bundleId)'"])
        
        if result.0 == 0 && !result.1.isEmpty {
            let paths = result.1.components(separatedBy: "\n").filter { !$0.isEmpty }
            if let firstPath = paths.first {
                NSLog("LowDataHelper: Found app at: \(firstPath)")
                return firstPath
            }
        }
        
        NSLog("LowDataHelper: Could not find application for bundle ID: \(bundleId)")
        return nil
    }
    
    private func getExecutableName(from appPath: String) -> String? {
        if appPath.hasSuffix(".app") {
            // Extract bundle executable name from Info.plist
            let infoPlistPath = "\(appPath)/Contents/Info.plist"
            let plistResult = runCommand("/usr/bin/plutil", arguments: ["-extract", "CFBundleExecutable", "raw", infoPlistPath])
            
            if plistResult.0 == 0 {
                let execName = plistResult.1.trimmingCharacters(in: .whitespacesAndNewlines)
                NSLog("LowDataHelper: Found executable name: \(execName)")
                return execName
            } else {
                // Fallback: use app name
                let appName = URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
                NSLog("LowDataHelper: Using app name as executable: \(appName)")
                return appName
            }
        } else {
            // For non-app bundles, return the last path component
            return URL(fileURLWithPath: appPath).lastPathComponent
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