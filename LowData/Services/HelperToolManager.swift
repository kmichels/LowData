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
        checkHelperStatus()
        
        // Periodically check helper status to stay in sync
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkHelperStatus()
            }
        }
    }
    
    private func setupDaemonService() {
        // SMAppService requires just the plist filename without path
        // The plist must be in Contents/Library/LaunchDaemons/
        // Use just the filename without the .plist extension
        daemonService = SMAppService.daemon(plistName: "com.lowdata.helper")
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
            isHelperInstalled = true
            
            // Try to connect and get version
            verifyHelperConnection()
            
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
    
    private func verifyHelperConnection() {
        print("HelperToolManager: Verifying helper connection...")
        
        // Try to connect to the helper via XPC
        let connection = NSXPCConnection(machServiceName: helperBundleID)
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
        
        let connection = NSXPCConnection(machServiceName: helperBundleID)
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