import Foundation
import Network

// Network profile that stores network characteristics
struct NetworkProfile: Codable, Identifiable, Equatable {
    let id = UUID()
    let ssid: String?
    let bssid: String?  // MAC address of router for more specific identification
    let name: String
    let isTrusted: Bool
    let dateAdded: Date
    let lastSeen: Date
    
    // Create a key for identifying unique networks
    var networkKey: String {
        if let ssid = ssid, !ssid.isEmpty {
            return ssid
        }
        return "Ethernet"
    }
}

@MainActor
class NetworkProfileManager: ObservableObject {
    @Published var profiles: [NetworkProfile] = []
    @Published var currentProfile: NetworkProfile?
    @Published var isTravelMode: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let profilesKey = "networkProfiles"
    private let travelModeKey = "travelModeEnabled"
    
    init() {
        loadProfiles()
        loadTravelMode()
    }
    
    // MARK: - Profile Management
    
    func loadProfiles() {
        if let data = userDefaults.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([NetworkProfile].self, from: data) {
            profiles = decoded
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            userDefaults.set(encoded, forKey: profilesKey)
        }
    }
    
    func addOrUpdateProfile(ssid: String?, bssid: String?, name: String, isTrusted: Bool) {
        let networkKey = ssid ?? "Ethernet"
        
        // Check if profile already exists
        if let index = profiles.firstIndex(where: { $0.networkKey == networkKey }) {
            // Update existing profile
            var updatedProfile = profiles[index]
            updatedProfile = NetworkProfile(
                ssid: ssid,
                bssid: bssid,
                name: name,
                isTrusted: isTrusted,
                dateAdded: updatedProfile.dateAdded,
                lastSeen: Date()
            )
            profiles[index] = updatedProfile
        } else {
            // Add new profile
            let newProfile = NetworkProfile(
                ssid: ssid,
                bssid: bssid,
                name: name,
                isTrusted: isTrusted,
                dateAdded: Date(),
                lastSeen: Date()
            )
            profiles.append(newProfile)
        }
        
        saveProfiles()
    }
    
    func removeProfile(_ profile: NetworkProfile) {
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }
    
    func trustProfile(_ profile: NetworkProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            var updatedProfile = profiles[index]
            updatedProfile = NetworkProfile(
                ssid: updatedProfile.ssid,
                bssid: updatedProfile.bssid,
                name: updatedProfile.name,
                isTrusted: true,
                dateAdded: updatedProfile.dateAdded,
                lastSeen: Date()
            )
            profiles[index] = updatedProfile
            saveProfiles()
            evaluateTravelMode()
        }
    }
    
    func untrustProfile(_ profile: NetworkProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            var updatedProfile = profiles[index]
            updatedProfile = NetworkProfile(
                ssid: updatedProfile.ssid,
                bssid: updatedProfile.bssid,
                name: updatedProfile.name,
                isTrusted: false,
                dateAdded: updatedProfile.dateAdded,
                lastSeen: Date()
            )
            profiles[index] = updatedProfile
            saveProfiles()
            evaluateTravelMode()
        }
    }
    
    // MARK: - Network Detection
    
    func detectCurrentNetwork(ssid: String?, bssid: String? = nil) {
        let networkKey = ssid ?? "Ethernet"
        
        // Check if we know this network
        if let profile = profiles.first(where: { $0.networkKey == networkKey }) {
            currentProfile = profile
            
            // Update last seen
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                var updatedProfile = profiles[index]
                updatedProfile = NetworkProfile(
                    ssid: updatedProfile.ssid,
                    bssid: updatedProfile.bssid,
                    name: updatedProfile.name,
                    isTrusted: updatedProfile.isTrusted,
                    dateAdded: updatedProfile.dateAdded,
                    lastSeen: Date()
                )
                profiles[index] = updatedProfile
                saveProfiles()
            }
        } else {
            // New network detected
            let newProfile = NetworkProfile(
                ssid: ssid,
                bssid: bssid,
                name: networkKey,
                isTrusted: false,  // Default to untrusted
                dateAdded: Date(),
                lastSeen: Date()
            )
            profiles.append(newProfile)
            currentProfile = newProfile
            saveProfiles()
        }
        
        evaluateTravelMode()
    }
    
    // MARK: - Travel Mode
    
    func loadTravelMode() {
        isTravelMode = userDefaults.bool(forKey: travelModeKey)
    }
    
    func saveTravelMode() {
        userDefaults.set(isTravelMode, forKey: travelModeKey)
    }
    
    func evaluateTravelMode() {
        // Travel mode is active when:
        // 1. We're on an untrusted network, OR
        // 2. We're on no known network
        if let current = currentProfile {
            isTravelMode = !current.isTrusted
        } else {
            isTravelMode = true  // Unknown networks are untrusted by default
        }
        saveTravelMode()
        
        // Apply or remove SMB blocks based on travel mode
        if isTravelMode {
            print("Travel Mode ACTIVE - Blocking SMB ports")
            applySMBBlocks()
        } else {
            print("Travel Mode INACTIVE - On trusted network")
            removeSMBBlocks()
        }
    }
    
    func toggleTravelMode() {
        isTravelMode.toggle()
        saveTravelMode()
        
        if isTravelMode {
            applySMBBlocks()
        } else {
            removeSMBBlocks()
        }
    }
    
    // MARK: - SMB Blocking
    
    private func applySMBBlocks() {
        // This will use pfctl to block SMB ports
        // For now, just log the action
        print("Would block SMB ports: 445, 139")
        // TODO: Implement actual pfctl commands with privileged helper
    }
    
    private func removeSMBBlocks() {
        // This will use pfctl to unblock SMB ports
        // For now, just log the action
        print("Would unblock SMB ports: 445, 139")
        // TODO: Implement actual pfctl commands with privileged helper
    }
}