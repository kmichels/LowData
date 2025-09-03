import Foundation
import SwiftUI

@MainActor
class BlockingRulesManager: ObservableObject {
    @Published var rules: [BlockingRule] = []
    @Published var isBlockingEnabled: Bool = true
    @Published var helperToolManager = HelperToolManager()
    @Published var lastError: String?
    
    private let rulesKey = "blockingRules"
    private let enabledKey = "blockingEnabled"
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadRules()
        loadEnabledState()
    }
    
    // MARK: - Persistence
    
    func loadRules() {
        // Try to load saved rules
        if let data = userDefaults.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([BlockingRule].self, from: data) {
            rules = decoded
        } else {
            // First time - load default rules
            rules = BlockingRule.defaultRules
            saveRules()
        }
    }
    
    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            userDefaults.set(encoded, forKey: rulesKey)
        }
    }
    
    func loadEnabledState() {
        // Default to true if not set
        if userDefaults.object(forKey: enabledKey) != nil {
            isBlockingEnabled = userDefaults.bool(forKey: enabledKey)
        } else {
            isBlockingEnabled = true
            saveEnabledState()
        }
    }
    
    func saveEnabledState() {
        userDefaults.set(isBlockingEnabled, forKey: enabledKey)
    }
    
    // MARK: - Rule Management
    
    func toggleRule(_ rule: BlockingRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
            applyRules()
        }
    }
    
    func addRule(_ rule: BlockingRule) {
        rules.append(rule)
        saveRules()
        if rule.isEnabled {
            applyRules()
        }
    }
    
    func removeRule(_ rule: BlockingRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
        applyRules()
    }
    
    func updateRule(_ rule: BlockingRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
            applyRules()
        }
    }
    
    // MARK: - Application Blocking
    
    func addApplicationRule(bundleId: String, name: String) {
        let rule = BlockingRule(
            name: name,
            type: .application(bundleId: bundleId, name: name),
            isEnabled: true,
            isUserAdded: true,
            description: "Block \(name) network access in Travel Mode"
        )
        addRule(rule)
    }
    
    func isApplicationBlocked(bundleId: String) -> Bool {
        return rules.contains { rule in
            if case .application(let id, _) = rule.type {
                return id == bundleId && rule.isEnabled
            }
            return false
        }
    }
    
    // MARK: - Port Blocking
    
    func addPortRule(port: Int, protocol: PortProtocol, name: String? = nil) {
        let ruleName = name ?? "Port \(port)"
        let rule = BlockingRule(
            name: ruleName,
            type: .port(number: port, protocol: `protocol`),
            isEnabled: true,
            isUserAdded: true,
            description: "Custom port rule"
        )
        addRule(rule)
    }
    
    // MARK: - Rule Application
    
    func applyRules() {
        guard isBlockingEnabled else {
            // If blocking is disabled, remove all rules
            removeAllActiveRules()
            return
        }
        
        // Check if helper is installed
        guard helperToolManager.isHelperInstalled else {
            print("Helper tool not installed - rules not applied")
            lastError = "Privileged helper not installed. Install it from Blocking Rules preferences."
            return
        }
        
        // Get enabled rules
        let enabledRules = rules.filter { $0.isEnabled }
        
        print("Applying \(enabledRules.count) blocking rules via helper")
        
        // Apply rules via helper tool
        helperToolManager.applyRules(enabledRules) { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.lastError = nil
                    print("Successfully applied blocking rules")
                } else {
                    self?.lastError = error
                    print("Failed to apply rules: \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    func removeAllActiveRules() {
        guard helperToolManager.isHelperInstalled else {
            print("Helper tool not installed - no rules to remove")
            return
        }
        
        print("Removing all blocking rules via helper")
        
        helperToolManager.removeAllRules { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.lastError = nil
                    print("Successfully removed all blocking rules")
                } else {
                    self?.lastError = error
                    print("Failed to remove rules: \(error ?? "Unknown error")")
                }
            }
        }
    }
    
    func installHelper(completion: @escaping (Bool, String?) -> Void) {
        helperToolManager.installHelper { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.lastError = nil
                    // Apply rules after successful installation
                    self?.applyRules()
                } else {
                    self?.lastError = error
                }
                completion(success, error)
            }
        }
    }
    
    // MARK: - Travel Mode Integration
    
    func handleTravelModeChange(isActive: Bool) {
        if isActive && isBlockingEnabled {
            applyRules()
        } else {
            removeAllActiveRules()
        }
    }
    
    // MARK: - Statistics
    
    var enabledRulesCount: Int {
        rules.filter { $0.isEnabled }.count
    }
    
    var serviceRules: [BlockingRule] {
        rules.filter {
            if case .service = $0.type { return true }
            return false
        }
    }
    
    var applicationRules: [BlockingRule] {
        rules.filter {
            if case .application = $0.type { return true }
            return false
        }
    }
    
    var portRules: [BlockingRule] {
        rules.filter {
            switch $0.type {
            case .port, .portRange:
                return true
            default:
                return false
            }
        }
    }
}