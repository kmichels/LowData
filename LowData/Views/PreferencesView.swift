import SwiftUI

struct PreferencesView: View {
    @Binding var runInMenuBar: Bool
    @EnvironmentObject var trafficMonitor: TrafficMonitor
    @ObservedObject var profileManager: NetworkProfileManager
    @AppStorage("updateInterval") private var updateInterval: Double = 2.0
    @AppStorage("displayUnits") private var displayUnits: String = "bits"
    @AppStorage("showSystemProcesses") private var showSystemProcesses = false
    @AppStorage("darkModeSupport") private var darkModeSupport = true
    
    init(runInMenuBar: Binding<Bool>, profileManager: NetworkProfileManager) {
        self._runInMenuBar = runInMenuBar
        self.profileManager = profileManager
    }
    
    var body: some View {
        TabView {
            GeneralTab(runInMenuBar: $runInMenuBar)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            MonitoringTab(
                updateInterval: $updateInterval,
                displayUnits: $displayUnits,
                showSystemProcesses: $showSystemProcesses
            )
            .tabItem {
                Label("Monitoring", systemImage: "network")
            }
            
            TravelModeView(profileManager: profileManager)
                .tabItem {
                    Label("Travel Mode", systemImage: "lock.shield")
                }
            
            AppearanceTab(darkModeSupport: $darkModeSupport)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
            }
        }
        .frame(width: 450, height: 400)
    }
}

struct GeneralTab: View {
    @Binding var runInMenuBar: Bool
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    
    var body: some View {
        Form {
            Section {
                Toggle("Run in menu bar", isOn: $runInMenuBar)
                    .help("Show Low Data in the menu bar instead of the dock")
                
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .help("Automatically start Low Data when you log in")
                    .disabled(true) // TODO: Implement launch at login
            }
            
            Section("Behavior") {
                HStack {
                    Text("When running in menu bar:")
                    Spacer()
                }
                .font(.headline)
                
                Text("• Click the menu bar icon to view network traffic")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Current transfer rate shown in menu bar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• App won't appear in dock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct MonitoringTab: View {
    @Binding var updateInterval: Double
    @Binding var displayUnits: String
    @Binding var showSystemProcesses: Bool
    
    var body: some View {
        Form {
            Section("Update Settings") {
                HStack {
                    Text("Update interval:")
                    Slider(value: $updateInterval, in: 1...10, step: 0.5)
                    Text("\(updateInterval, specifier: "%.1f")s")
                        .frame(width: 40)
                }
                .help("How often to refresh network data")
            }
            
            Section("Display Options") {
                Picker("Display units:", selection: $displayUnits) {
                    Text("Bits (Kbps, Mbps)").tag("bits")
                    Text("Bytes (KB/s, MB/s)").tag("bytes")
                }
                .pickerStyle(.radioGroup)
                .help("Choose how to display transfer rates")
                
                Toggle("Show system processes", isOn: $showSystemProcesses)
                    .help("Include system processes like mDNSResponder in the list")
            }
            
            Section("Filtering") {
                Text("Coming soon: App filtering rules")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AppearanceTab: View {
    @Binding var darkModeSupport: Bool
    @AppStorage("accentColor") private var accentColor = "blue"
    
    var body: some View {
        Form {
            Section("Theme") {
                Toggle("Automatic dark mode", isOn: $darkModeSupport)
                    .help("Automatically switch between light and dark appearance")
            }
            
            Section("Colors") {
                Picker("Accent color:", selection: $accentColor) {
                    Label("Blue", systemImage: "circle.fill")
                        .foregroundColor(.blue)
                        .tag("blue")
                    Label("Green", systemImage: "circle.fill")
                        .foregroundColor(.green)
                        .tag("green")
                    Label("Orange", systemImage: "circle.fill")
                        .foregroundColor(.orange)
                        .tag("orange")
                    Label("Red", systemImage: "circle.fill")
                        .foregroundColor(.red)
                        .tag("red")
                }
                .pickerStyle(.radioGroup)
            }
            
            Section("Menu Bar") {
                Text("Menu bar icon style:")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    VStack {
                        Text("📊")
                            .font(.title)
                        Text("Emoji")
                            .font(.caption)
                    }
                    
                    VStack {
                        Image(systemName: "network")
                            .font(.title)
                        Text("System")
                            .font(.caption)
                    }
                    .opacity(0.5)
                }
            }
        }
        .padding()
    }
}

#Preview {
    PreferencesView(runInMenuBar: .constant(false), profileManager: NetworkProfileManager())
        .environmentObject(TrafficMonitor())
}