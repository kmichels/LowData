import Foundation
import ServiceManagement

@MainActor
class HelperToolManager: ObservableObject {
    
    // MARK: - Properties
    @Published var isHelperInstalled = false
    @Published var helperVersion: String?
    @Published var installationError: String?
    
    private let helperBundleID = "com.lowdata.helper"
    private var helperConnection: NSXPCConnection?
    private var daemonService: SMAppService?
    
    // MARK: - Initialization
    init() {
        setupDaemonService()
        
        // Check status asynchronously to avoid blocking UI
        Task { @MainActor in
            checkHelperStatus()
        }
        
        // Periodically check helper status to stay in sync
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkHelperStatus()
            }
        }
    }
    
    private func setupDaemonService() {
        // SMAppService requires the plist filename WITH the .plist extension
        // The plist must be in Contents/Library/LaunchDaemons/
        // ChatGPT research confirms: include .plist extension in the name
        daemonService = SMAppService.daemon(plistName: "com.lowdata.helper.plist")
    }
    
    // MARK: - Helper Installation using SMAppService
    
    func installHelper(completion: @escaping (Bool, String?) -> Void) {
        guard let service = daemonService else {
            completion(false, "Failed to initialize daemon service")
            return
        }
        
        Task {
            do {
                // Register the daemon with the system
                try service.register()
                
                // Update status on main actor
                await MainActor.run {
                    self.installationError = nil
                    self.checkHelperStatus()
                    // Let checkHelperStatus determine if it's really installed
                    completion(self.isHelperInstalled, nil)
                }
            } catch {
                let errorMessage = "Failed to register helper: \(error.localizedDescription)"
                
                await MainActor.run {
                    self.isHelperInstalled = false
                    self.installationError = errorMessage
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    func uninstallHelper(completion: @escaping (Bool, String?) -> Void) {
        guard let service = daemonService else {
            completion(false, "Failed to initialize daemon service")
            return
        }
        
        Task {
            do {
                // Check current status first
                let status = service.status
                
                switch status {
                case .notRegistered:
                    await MainActor.run {
                        completion(true, "Helper was not installed")
                    }
                    
                case .enabled, .requiresApproval, .notFound:
                    // Try to unregister
                    try await service.unregister()
                    
                    await MainActor.run {
                        self.isHelperInstalled = false
                        self.helperVersion = nil
                        completion(true, nil)
                    }
                    
                @unknown default:
                    await MainActor.run {
                        completion(false, "Unknown helper status")
                    }
                }
            } catch {
                let errorMessage = "Failed to unregister helper: \(error.localizedDescription)"
                
                await MainActor.run {
                    completion(false, errorMessage)
                }
            }
        }
    }
    
    func checkHelperStatus() {
        guard let service = daemonService else {
            print("HelperToolManager: No daemon service available")
            isHelperInstalled = false
            return
        }
        
        // Check registration status
        let status = service.status
        print("HelperToolManager: Helper status = \(status)")
        
        switch status {
        case .enabled:
            // Helper is registered and enabled
            print("HelperToolManager: Helper is enabled")
            
            // For now, assume it's installed if registered
            // Then verify connection async without blocking
            isHelperInstalled = true
            
            // Check connection in background
            Task {
                await checkHelperProcessAsync()
            }
            
        case .requiresApproval:
            // User needs to approve in System Settings
            print("HelperToolManager: Helper requires approval")
            isHelperInstalled = false
            installationError = "Helper requires approval in System Settings > Privacy & Security"
            
        case .notRegistered:
            // Helper is not installed
            print("HelperToolManager: Helper not registered")
            isHelperInstalled = false
            helperVersion = nil
            
        case .notFound:
            // Helper binary not found in bundle
            print("HelperToolManager: Helper not found in bundle")
            isHelperInstalled = false
            installationError = "Helper binary not found in application bundle"
            
        @unknown default:
            print("HelperToolManager: Unknown status")
            isHelperInstalled = false
            installationError = "Unknown helper status"
        }
    }
    
    private func checkHelperProcessAsync() async {
        print("HelperToolManager: Checking helper process async...")
        
        // Don't block on process checking - just verify with XPC connection
        // The XPC connection attempt will tell us if the helper is actually running
        await withCheckedContinuation { continuation in
            verifyHelperConnectionWithTimeout { [weak self] success in
                Task { @MainActor in
                    if !success {
                        self?.helperVersion = nil
                        self?.installationError = "Helper registered but not responding"
                        print("HelperToolManager: Helper not responding to XPC")
                    } else {
                        self?.installationError = nil
                        print("HelperToolManager: Helper is responding to XPC")
                    }
                }
                continuation.resume()
            }
        }
    }
    
    private func helperProcessIsRunning() -> Bool {
        // Check if the helper process is actually running
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("com.lowdata.helper")
            }
        } catch {
            print("HelperToolManager: Failed to check process status: \(error)")
        }
        
        return false
    }
    
    private func verifyHelperConnectionWithTimeout(completion: @escaping (Bool) -> Void) {
        print("HelperToolManager: Attempting to verify helper connection...")
        
        let connection = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LowDataHelperProtocol.self)
        connection.resume()
        
        var responded = false
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            print("HelperToolManager: Connection failed: \(error.localizedDescription)")
            if !responded {
                responded = true
                completion(false)
            }
        } as? LowDataHelperProtocol
        
        helper?.getHelperVersion { version in
            print("HelperToolManager: Helper responded with version: \(version)")
            if !responded {
                responded = true
                Task { @MainActor in
                    self.helperVersion = version
                    completion(true)
                }
            }
        }
        
        // Timeout after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            connection.invalidate()
            if !responded {
                responded = true
                print("HelperToolManager: Connection timed out")
                completion(false)
            }
        }
    }
    
    private func verifyHelperConnection() {
        print("HelperToolManager: Verifying helper connection...")
        
        // Try to connect to the helper via XPC
        let connection = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LowDataHelperProtocol.self)
        connection.resume()
        
        let helper = connection.remoteObjectProxyWithErrorHandler { [weak self] error in
            print("HelperToolManager: XPC connection error: \(error.localizedDescription)")
            Task { @MainActor in
                // Don't reset isHelperInstalled here - the helper is installed per SMAppService
                // Just note that we can't connect to it right now
                self?.helperVersion = nil
                self?.installationError = "Cannot connect to helper: \(error.localizedDescription)"
                print("HelperToolManager: Helper installed but not responding. It may need to be started.")
            }
        } as? LowDataHelperProtocol
        
        helper?.getHelperVersion { [weak self] version in
            print("HelperToolManager: Successfully connected to helper, version: \(version)")
            Task { @MainActor in
                self?.helperVersion = version
                self?.installationError = nil
            }
        }
        
        // Clean up connection after check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            connection.invalidate()
        }
    }
    
    // MARK: - Helper Communication
    
    private func getHelperConnection() -> NSXPCConnection {
        if let connection = helperConnection {
            return connection
        }
        
        let connection = NSXPCConnection(machServiceName: helperBundleID, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: LowDataHelperProtocol.self)
        
        connection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.helperConnection = nil
            }
        }
        
        connection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.helperConnection = nil
            }
        }
        
        connection.resume()
        helperConnection = connection
        return connection
    }
    
    func applyRules(_ rules: [BlockingRule], completion: @escaping (Bool, String?) -> Void) {
        guard isHelperInstalled else {
            completion(false, "Helper tool not installed")
            return
        }
        
        // Convert BlockingRule objects to dictionaries
        var rulesDicts = [[String: Any]]()
        
        for rule in rules where rule.isEnabled {
            var ruleDict = [String: Any]()
            
            switch rule.type {
            case .port(let number, let proto):
                ruleDict["type"] = "port"
                ruleDict["port"] = number
                ruleDict["protocol"] = proto.rawValue
                
            case .portRange(let start, let end, let proto):
                ruleDict["type"] = "portRange"
                ruleDict["startPort"] = start
                ruleDict["endPort"] = end
                ruleDict["protocol"] = proto.rawValue
                
            case .service(_, let ports):
                ruleDict["type"] = "service"
                var portDicts = [[String: Any]]()
                for portRule in ports {
                    portDicts.append([
                        "port": portRule.port,
                        "protocol": portRule.protocol.rawValue
                    ])
                }
                ruleDict["ports"] = portDicts
                
            case .application(let bundleId, let name):
                ruleDict["type"] = "application"
                ruleDict["bundleId"] = bundleId
                ruleDict["name"] = name
                
                // Also include known ports for this application if available
                if let appPorts = getKnownPortsForApp(bundleId) {
                    ruleDict["ports"] = appPorts
                }
            }
            
            rulesDicts.append(ruleDict)
        }
        
        let connection = getHelperConnection()
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "Failed to connect to helper: \(error.localizedDescription)")
        } as? LowDataHelperProtocol
        
        helper?.applyBlockingRules(rulesDicts) { success, error in
            Task { @MainActor in
                completion(success, error)
            }
        }
    }
    
    func removeAllRules(completion: @escaping (Bool, String?) -> Void) {
        guard isHelperInstalled else {
            completion(false, "Helper tool not installed")
            return
        }
        
        let connection = getHelperConnection()
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            completion(false, "Failed to connect to helper: \(error.localizedDescription)")
        } as? LowDataHelperProtocol
        
        helper?.removeAllBlockingRules { success, error in
            Task { @MainActor in
                completion(success, error)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getKnownPortsForApp(_ bundleId: String) -> [[String: Any]]? {
        // Return known ports for common applications
        switch bundleId {
        case "com.apple.ScreenSharing":
            return [["port": 5900, "protocol": "tcp"]]
        case "com.apple.RemoteDesktop":
            return [["port": 3283, "protocol": "tcp"], ["port": 5900, "protocol": "tcp"]]
        default:
            return nil
        }
    }
}