import Foundation

// LowData Privileged Helper Tool for macOS 15+
// Uses SMAppService for modern daemon management

class LowDataHelper: NSObject {
    
    // MARK: - Properties
    private let listener: NSXPCListener
    
    // MARK: - Initialization
    override init() {
        self.listener = NSXPCListener(machServiceName: "com.lowdata.helper")
        super.init()
    }
    
    func run() {
        // Log startup with more details
        NSLog("LowDataHelper: Starting helper daemon (SMAppService version)")
        NSLog("LowDataHelper: Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        NSLog("LowDataHelper: Bundle path: \(Bundle.main.bundlePath)")
        NSLog("LowDataHelper: Mach service name: com.lowdata.helper")
        
        // Configure listener
        listener.delegate = self
        
        // Start listening
        listener.resume()
        NSLog("LowDataHelper: XPC listener resumed, waiting for connections...")
        
        // Keep the helper running
        RunLoop.current.run()
    }
}

// MARK: - NSXPCListenerDelegate
extension LowDataHelper: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Log connection attempt
        NSLog("LowDataHelper: Received connection request")
        
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
        
        NSLog("LowDataHelper: Connection accepted")
        return true
    }
}

// MARK: - Helper Service Implementation
class LowDataHelperService: NSObject, LowDataHelperProtocol {
    
    private let helperVersion = "2.0.0" // Version 2.0 for SMAppService
    private let pfctlPath = "/sbin/pfctl"
    private let rulesFile = "/tmp/lowdata_rules.conf"
    
    func getHelperVersion(reply: @escaping (String) -> Void) {
        NSLog("LowDataHelper: Version request - returning \(helperVersion)")
        reply(helperVersion)
    }
    
    func applyBlockingRules(_ rules: [[String: Any]], reply: @escaping (Bool, String?) -> Void) {
        NSLog("LowDataHelper: Applying \(rules.count) blocking rules")
        
        // Generate pfctl rules
        var pfRules = [String]()
        
        // Add a header comment
        pfRules.append("# Low Data Blocking Rules - Generated \(Date())")
        pfRules.append("")
        
        for rule in rules {
            guard let type = rule["type"] as? String else { continue }
            
            switch type {
            case "port":
                if let port = rule["port"] as? Int,
                   let proto = rule["protocol"] as? String {
                    // Block outgoing traffic to this port
                    pfRules.append("block drop out proto \(proto) from any to any port \(port)")
                }
                
            case "portRange":
                if let startPort = rule["startPort"] as? Int,
                   let endPort = rule["endPort"] as? Int,
                   let proto = rule["protocol"] as? String {
                    // Block range of ports
                    pfRules.append("block drop out proto \(proto) from any to any port \(startPort):\(endPort)")
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
                    
                    // Block by known ports if available
                    if let appPorts = rule["ports"] as? [[String: Any]] {
                        for portInfo in appPorts {
                            if let port = portInfo["port"] as? Int,
                               let proto = portInfo["protocol"] as? String {
                                pfRules.append("block drop out proto \(proto) from any to any port \(port)")
                            }
                        }
                    }
                    
                    // Method 2: Block by process (requires additional setup)
                    // This is more reliable than PID-based blocking
                    if let appPath = getApplicationPath(for: bundleId),
                       let executable = getExecutableName(from: appPath) {
                        // Create a table to track this app's connections
                        let tableName = bundleId.replacingOccurrences(of: ".", with: "_")
                        pfRules.append("table <\(tableName)_blocked> persist")
                        
                        // Note: Full application blocking would require additional kernel-level support
                        pfRules.append("# Note: Full app-level blocking requires additional system configuration")
                    }
                }
                
            default:
                NSLog("LowDataHelper: Unknown rule type: \(type)")
            }
        }
        
        // Write rules to file
        let rulesContent = pfRules.joined(separator: "\n")
        
        do {
            try rulesContent.write(toFile: rulesFile, atomically: true, encoding: .utf8)
            NSLog("LowDataHelper: Wrote \(pfRules.count) rules to \(rulesFile)")
            
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
        // Use mdfind to locate app by bundle ID
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
NSLog("LowDataHelper: Initializing helper daemon")
let helper = LowDataHelper()
helper.run()