import SwiftUI

struct BlockingRulesView: View {
    @ObservedObject var rulesManager: BlockingRulesManager
    @State private var showAddPort = false
    @State private var showAddApp = false
    @State private var newPortNumber = ""
    @State private var newPortProtocol = PortProtocol.tcp
    @State private var newPortName = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            BlockingRulesHeader(rulesManager: rulesManager)
            
            Divider()
            
            // Rules List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Services Section
                    RulesSection(
                        title: "Services & Ports",
                        icon: "server.rack",
                        rules: rulesManager.serviceRules + rulesManager.portRules,
                        rulesManager: rulesManager,
                        onAdd: {
                            showAddPort = true
                        }
                    )
                    
                    // Applications Section
                    RulesSection(
                        title: "Applications",
                        icon: "app.badge",
                        rules: rulesManager.applicationRules,
                        rulesManager: rulesManager,
                        onAdd: {
                            showAddApp = true
                        }
                    )
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddPort) {
            AddPortRuleView(rulesManager: rulesManager, isPresented: $showAddPort)
        }
        .sheet(isPresented: $showAddApp) {
            AddApplicationRuleView(rulesManager: rulesManager, isPresented: $showAddApp)
        }
    }
}

struct BlockingRulesHeader: View {
    @ObservedObject var rulesManager: BlockingRulesManager
    @State private var showInstallAlert = false
    @State private var installError: String?
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocking Rules")
                        .font(.headline)
                    
                    Text("\(rulesManager.enabledRulesCount) rules active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Helper installation status
                if !rulesManager.helperToolManager.isHelperInstalled {
                    Button(action: {
                        showInstallAlert = true
                    }) {
                        Label("Install Helper", systemImage: "arrow.down.circle")
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
                
                Toggle("Enable Blocking", isOn: $rulesManager.isBlockingEnabled)
                    .toggleStyle(.switch)
                    .disabled(!rulesManager.helperToolManager.isHelperInstalled)
                    .onChange(of: rulesManager.isBlockingEnabled) { _, _ in
                        rulesManager.saveEnabledState()
                        rulesManager.applyRules()
                    }
            }
            .padding()
            
            // Show helper status
            if !rulesManager.helperToolManager.isHelperInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Privileged helper not installed. Click 'Install Helper' to enable blocking.")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else if rulesManager.isBlockingEnabled && rulesManager.enabledRulesCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Rules are applied when Travel Mode is active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            
            // Show any errors
            if let error = rulesManager.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Install Privileged Helper", isPresented: $showInstallAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Install") {
                rulesManager.installHelper { success, error in
                    if !success {
                        installError = error
                    }
                }
            }
        } message: {
            Text("The privileged helper tool is required to apply network blocking rules. You will be prompted for your administrator password.")
        }
        .alert("Installation Failed", isPresented: .constant(installError != nil)) {
            Button("OK") {
                installError = nil
            }
        } message: {
            if let error = installError {
                Text(error)
            }
        }
    }
}

struct RulesSection: View {
    let title: String
    let icon: String
    let rules: [BlockingRule]
    @ObservedObject var rulesManager: BlockingRulesManager
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            
            // Rules List
            if rules.isEmpty {
                Text("No \(title.lowercased()) configured")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 2) {
                    ForEach(rules) { rule in
                        BlockingRuleRow(rule: rule, rulesManager: rulesManager)
                    }
                }
            }
        }
    }
}

struct BlockingRuleRow: View {
    let rule: BlockingRule
    @ObservedObject var rulesManager: BlockingRulesManager
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in rulesManager.toggleRule(rule) }
            ))
            .toggleStyle(.checkbox)
            
            // Icon
            Image(systemName: rule.type.icon)
                .foregroundColor(rule.isEnabled ? .blue : .secondary)
                .frame(width: 20)
            
            // Name and Description
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.system(size: 13))
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                
                if !rule.description.isEmpty {
                    Text(rule.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Type indicator
            if rule.isUserAdded {
                Text("Custom")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Delete button (only for user-added rules)
            if rule.isUserAdded {
                Button(action: {
                    rulesManager.removeRule(rule)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .opacity(isHovered ? 1 : 0.5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct AddPortRuleView: View {
    @ObservedObject var rulesManager: BlockingRulesManager
    @Binding var isPresented: Bool
    
    @State private var portNumber = ""
    @State private var portProtocol = PortProtocol.tcp
    @State private var ruleName = ""
    @State private var description = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Port Rule")
                .font(.headline)
            
            Form {
                TextField("Rule Name", text: $ruleName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Port Number", text: $portNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Picker("Protocol", selection: $portProtocol) {
                    Text("TCP").tag(PortProtocol.tcp)
                    Text("UDP").tag(PortProtocol.udp)
                    Text("Both").tag(PortProtocol.both)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                TextField("Description (optional)", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add Rule") {
                    if let port = Int(portNumber), !ruleName.isEmpty {
                        let rule = BlockingRule(
                            name: ruleName,
                            type: .port(number: port, protocol: portProtocol),
                            isEnabled: true,
                            isUserAdded: true,
                            description: description
                        )
                        rulesManager.addRule(rule)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(portNumber.isEmpty || ruleName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

struct AddApplicationRuleView: View {
    @ObservedObject var rulesManager: BlockingRulesManager
    @Binding var isPresented: Bool
    
    @State private var selectedApp: URL?
    @State private var appName = ""
    @State private var bundleId = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Application Rule")
                .font(.headline)
            
            Text("Select an application to block in Travel Mode")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Choose Application...") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.canChooseFiles = true
                panel.allowedContentTypes = [.application]
                panel.directoryURL = URL(fileURLWithPath: "/Applications")
                
                if panel.runModal() == .OK, let url = panel.url {
                    selectedApp = url
                    // Extract app info
                    if let bundle = Bundle(url: url) {
                        appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
                        bundleId = bundle.bundleIdentifier ?? ""
                    }
                }
            }
            
            if selectedApp != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "app")
                        Text(appName)
                            .font(.system(size: 13, weight: .medium))
                    }
                    
                    Text(bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Add Rule") {
                    if !bundleId.isEmpty && !appName.isEmpty {
                        rulesManager.addApplicationRule(bundleId: bundleId, name: appName)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(bundleId.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}

#Preview {
    BlockingRulesView(rulesManager: BlockingRulesManager())
        .frame(width: 500, height: 400)
}