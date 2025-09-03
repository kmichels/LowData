import SwiftUI

struct TravelModeView: View {
    @ObservedObject var profileManager: NetworkProfileManager
    @State private var showAddProfile = false
    @State private var newProfileName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Travel Mode Status Header
            TravelModeHeader(profileManager: profileManager)
            
            Divider()
            
            // Network Profiles List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Network Profiles")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    if profileManager.profiles.isEmpty {
                        EmptyProfilesView()
                            .padding()
                    } else {
                        ForEach(profileManager.profiles.sorted(by: { $0.lastSeen > $1.lastSeen })) { profile in
                            NetworkProfileRow(profile: profile, profileManager: profileManager)
                        }
                    }
                }
                .padding(.bottom)
            }
        }
    }
}

struct TravelModeHeader: View {
    @ObservedObject var profileManager: NetworkProfileManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: profileManager.isTravelMode ? "lock.shield.fill" : "wifi")
                    .font(.largeTitle)
                    .foregroundColor(profileManager.isTravelMode ? .orange : .blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileManager.isTravelMode ? "Travel Mode Active" : "On Trusted Network")
                        .font(.headline)
                    
                    if let current = profileManager.currentProfile {
                        Text("Connected to: \(current.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Network not recognized")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Toggle("", isOn: .init(
                    get: { profileManager.isTravelMode },
                    set: { _ in profileManager.toggleTravelMode() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding()
            
            if profileManager.isTravelMode {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("SMB file sharing ports are blocked for security")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct NetworkProfileRow: View {
    let profile: NetworkProfile
    @ObservedObject var profileManager: NetworkProfileManager
    @State private var isHovered = false
    @State private var showEditName = false
    @State private var editedName = ""
    
    var isCurrentNetwork: Bool {
        profileManager.currentProfile?.id == profile.id
    }
    
    var body: some View {
        HStack {
            // Network icon
            Image(systemName: profile.ssid != nil ? "wifi" : "network")
                .font(.title2)
                .foregroundColor(isCurrentNetwork ? .blue : .secondary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if showEditName {
                        TextField("Network name", text: $editedName, onCommit: {
                            // Save the edited name
                            profileManager.addOrUpdateProfile(
                                ssid: profile.ssid,
                                bssid: profile.bssid,
                                name: editedName.isEmpty ? profile.name : editedName,
                                isTrusted: profile.isTrusted
                            )
                            showEditName = false
                        })
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 150)
                        
                        Button("Cancel") {
                            showEditName = false
                            editedName = profile.name
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    } else {
                        Text(profile.name)
                            .font(.system(size: 13, weight: .medium))
                        
                        if isCurrentNetwork {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    if let ssid = profile.ssid {
                        Text(ssid)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Last seen: \(profile.lastSeen, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Trust status and actions
            HStack(spacing: 8) {
                if profile.isTrusted {
                    Label("Trusted", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Untrusted", systemImage: "xmark.shield")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Menu {
                    if profile.isTrusted {
                        Button(action: {
                            profileManager.untrustProfile(profile)
                        }) {
                            Label("Mark as Untrusted", systemImage: "xmark.shield")
                        }
                    } else {
                        Button(action: {
                            profileManager.trustProfile(profile)
                        }) {
                            Label("Mark as Trusted", systemImage: "checkmark.shield")
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        editedName = profile.name
                        showEditName = true
                    }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(action: {
                        profileManager.removeProfile(profile)
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct EmptyProfilesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Network Profiles")
                .font(.headline)
            
            Text("Networks you connect to will appear here.\nYou can mark them as trusted or untrusted.")
                .multilineTextAlignment(.center)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    TravelModeView(profileManager: NetworkProfileManager())
        .frame(width: 450, height: 400)
}