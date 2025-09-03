import SwiftUI
import AppKit

@main
struct LowDataApp: App {
    @StateObject private var trafficMonitor = TrafficMonitor()
    @StateObject private var networkDetector = NetworkDetector()
    @AppStorage("runInMenuBar") private var runInMenuBar = false
    @State private var menuBarController: MenuBarController?
    @State private var mainWindowController: NSWindowController?
    @State private var hasSetupInitialMode = false
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(trafficMonitor)
                .environmentObject(networkDetector)
                .onChange(of: runInMenuBar) { _, newValue in
                    // Handle mode changes from anywhere in the app
                    toggleMenuBarMode(newValue)
                }
                .task {
                    // Setup initial mode only once
                    if !hasSetupInitialMode {
                        hasSetupInitialMode = true
                        if runInMenuBar {
                            _ = await MainActor.run { @MainActor in
                                NSApp.setActivationPolicy(.accessory)
                                setupMenuBar()
                                // Close the main window in menubar mode
                                for window in NSApp.windows {
                                    if !window.className.contains("NSStatusBarWindow") &&
                                       !window.title.contains("Settings") &&
                                       !window.title.contains("Preferences") {
                                        window.close()
                                    }
                                }
                            }
                        } else {
                            // Ensure we're in regular mode
                            _ = await MainActor.run { @MainActor in
                                NSApp.setActivationPolicy(.regular)
                            }
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Settings are handled by the Settings scene
        }
        
        Settings {
            PreferencesView(runInMenuBar: $runInMenuBar, profileManager: networkDetector.profileManager)
                .environmentObject(trafficMonitor)
                .onChange(of: runInMenuBar) { _, newValue in
                    toggleMenuBarMode(newValue)
                }
        }
    }
    
    private func setupMenuBar() {
        if menuBarController == nil {
            menuBarController = MenuBarController(
                monitor: trafficMonitor,
                networkDetector: networkDetector,
                onModeChange: { enabled in
                    // Update the AppStorage value which will trigger onChange
                    UserDefaults.standard.set(enabled, forKey: "runInMenuBar")
                }
            )
        }
    }
    
    @MainActor
    private func toggleMenuBarMode(_ enabled: Bool) {
        if enabled {
            // Switch to menubar mode
            NSApp.setActivationPolicy(.accessory)
            setupMenuBar()
            
            // Close all non-settings windows - use a delay to ensure the menubar is setup first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for window in NSApp.windows {
                    if !window.title.contains("Settings") && 
                       !window.title.contains("Preferences") &&
                       !window.title.contains("General") &&
                       !window.className.contains("NSStatusBarWindow") &&
                       !window.className.contains("NSPopoverWindow") {
                        print("Closing window: \(window.title), class: \(window.className)")
                        window.close()
                    }
                }
                // Clean up the window controller
                self.mainWindowController = nil
            }
        } else {
            // Switch back to dock mode using the proven pattern from research
            print("Switching to dock mode...")
            
            // Clean up menubar first
            menuBarController = nil
            
            // Use the prohibited -> regular pattern with delay to fix menu bar issues
            NSApp.setActivationPolicy(.prohibited)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                
                // Check for existing main window
                var foundMainWindow = false
                for window in NSApp.windows {
                    print("Window: '\(window.title)', class: \(window.className), visible: \(window.isVisible)")
                    // Look specifically for our main app window
                    // Note: Empty title or "Item-0" might be our main window
                    if (window.className.contains("SwiftUI.AppKitWindow") || window.title == "Item-0" || window.title.isEmpty) &&
                       !window.title.contains("Settings") && 
                       !window.title.contains("Preferences") &&
                       !window.title.contains("General") &&
                       !window.className.contains("NSStatusBarWindow") &&
                       !window.className.contains("NSPopoverWindow") {
                        // Unhide and show the window
                        NSApp.unhide(nil)
                        window.setIsVisible(true)
                        window.makeKeyAndOrderFront(nil)
                        foundMainWindow = true
                        print("Found and showing existing window")
                        break
                    }
                }
                
                if !foundMainWindow {
                    print("No main window found, creating new one...")
                    // Create a new window manually with proper styling
                    let contentView = ContentView()
                        .environmentObject(self.trafficMonitor)
                        .environmentObject(self.networkDetector)
                        .frame(minWidth: 500, minHeight: 400)
                    
                    let hostingController = NSHostingController(rootView: contentView)
                    let window = NSWindow(contentViewController: hostingController)
                    window.title = "Low Data"
                    window.setContentSize(NSSize(width: 500, height: 400))
                    // Match the original window style from WindowGroup
                    window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.isMovableByWindowBackground = true
                    window.center()
                    
                    // Create and store window controller
                    let windowController = NSWindowController(window: window)
                    self.mainWindowController = windowController
                    
                    // Show the window
                    windowController.showWindow(nil)
                    window.makeKeyAndOrderFront(nil)
                    
                    // Focus toggle workaround to ensure window and menu bar appear
                    NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.activate(options: [])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        NSApp.activate(ignoringOtherApps: true)
                        window.makeKeyAndOrderFront(nil)
                    }
                    
                    print("Created new window: \(window)")
                }
            }
        }
    }
    
}