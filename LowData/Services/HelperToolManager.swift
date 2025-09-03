import Foundation
import ServiceManagement
import Security

// MARK: - Helper Tool Protocol (must match helper's protocol)
@objc protocol LowDataHelperProtocol {
    func applyBlockingRules(_ rules: [[String: Any]], reply: @escaping (Bool, String?) -> Void)
    func removeAllBlockingRules(reply: @escaping (Bool, String?) -> Void)
    func getHelperVersion(reply: @escaping (String) -> Void)
}

@MainActor
class HelperToolManager: ObservableObject {
    
    // MARK: - Properties
    @Published var isHelperInstalled = false
    @Published var helperVersion: String?
    
    private let helperBundleID = "com.lowdata.helper"
    private var helperConnection: NSXPCConnection?
    
    // MARK: - Initialization
    init() {
        checkHelperStatus()
    }
    
    // MARK: - Helper Installation
    
    func installHelper(completion: @escaping (Bool, String?) -> Void) {
        // Request authorization
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)
        
        guard authStatus == errAuthorizationSuccess else {
            completion(false, "Failed to create authorization")
            return
        }
        
        // Create authorization item for installing helper
        var authItem = AuthorizationItem(
            name: kSMRightBlessPrivilegedHelper,
            valueLength: 0,
            value: nil,
            flags: 0
        )
        
        var authRights = AuthorizationRights(
            count: 1,
            items: &authItem
        )
        
        let authFlags: AuthorizationFlags = [
            .interactionAllowed,
            .extendRights,
            .preAuthorize
        ]
        
        authStatus = AuthorizationCopyRights(
            authRef!,
            &authRights,
            nil,
            authFlags,
            nil
        )
        
        guard authStatus == errAuthorizationSuccess else {
            AuthorizationFree(authRef!, [])
            completion(false, "User cancelled authorization")
            return
        }
        
        // Install helper using SMJobBless
        var error: Unmanaged<CFError>?
        let success = SMJobBless(
            kSMDomainSystemLaunchd,
            helperBundleID as CFString,
            authRef,
            &error
        )
        
        AuthorizationFree(authRef!, [])
        
        if success {
            isHelperInstalled = true
            checkHelperStatus()
            completion(true, nil)
        } else {
            let errorString = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            completion(false, "Failed to install helper: \(errorString)")
        }
    }
    
    func checkHelperStatus() {
        // Check if helper is installed
        let connection = NSXPCConnection(machServiceName: helperBundleID)
        connection.remoteObjectInterface = NSXPCInterface(with: LowDataHelperProtocol.self)
        connection.resume()
        
        let helper = connection.remoteObjectProxyWithErrorHandler { error in
            Task { @MainActor in
                self.isHelperInstalled = false
                self.helperVersion = nil
            }
        } as? LowDataHelperProtocol
        
        helper?.getHelperVersion { version in
            Task { @MainActor in
                self.isHelperInstalled = true
                self.helperVersion = version
            }
        }
        
        // Keep connection briefly to check
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
}