import SwiftUI
import AppKit

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var monitor: TrafficMonitor
    private var networkDetector: NetworkDetector
    private var eventMonitor: Any?
    private var onModeChange: ((Bool) -> Void)?
    @AppStorage("menuBarIconStyle") private var menuBarIconStyle = "emoji" // "emoji" or "sfSymbol"
    
    init(monitor: TrafficMonitor, networkDetector: NetworkDetector, onModeChange: @escaping (Bool) -> Void) {
        self.monitor = monitor
        self.networkDetector = networkDetector
        self.onModeChange = onModeChange
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            updateButtonTitle()
            button.action = #selector(togglePopover)
            button.target = self
            
            // Add right-click menu
            _ = createContextMenu()  // Just validate it can be created
            statusItem?.menu = nil // Start with no menu, we'll set it on right-click
            
            // Monitor for right-clicks
            NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                if let button = self?.statusItem?.button,
                   let eventWindow = event.window,
                   eventWindow == button.window {
                    self?.statusItem?.menu = self?.createContextMenu()
                    button.performClick(nil)
                    
                    // Remove menu after showing
                    DispatchQueue.main.async {
                        self?.statusItem?.menu = nil
                    }
                    return nil // Consume the event
                }
                return event
            }
            
            print("MenuBar setup complete")
        }
        
        // Update the menubar text periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateButtonTitle()
            }
        }
        
        // Setup popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(monitor)
                .environmentObject(networkDetector)
        )
        
        // Setup event monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                self?.closePopover()
            }
        }
    }
    
    private func updateButtonTitle() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let button = self.statusItem?.button else { return }
            
            if self.menuBarIconStyle == "sfSymbol" {
                // Use SF Symbol
                if let image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Low Data") {
                    // Configure the image
                    let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular, scale: .medium)
                    let configuredImage = image.withSymbolConfiguration(config)
                    
                    button.image = configuredImage
                    button.imagePosition = .imageLeft
                    
                    if self.monitor.isMonitoring {
                        let rate = self.formatRate(self.monitor.totalRate)
                        button.title = " \(rate)"
                        button.toolTip = "Low Data - Click to view details"
                    } else {
                        button.title = ""
                        button.toolTip = "Low Data - Not monitoring"
                    }
                }
            } else {
                // Use emoji (default)
                button.image = nil
                if self.monitor.isMonitoring {
                    let rate = self.formatRate(self.monitor.totalRate)
                    button.title = "📊 \(rate)"
                    button.toolTip = "Low Data - Click to view details"
                } else {
                    button.title = "📊"
                    button.toolTip = "Low Data - Not monitoring"
                }
            }
        }
    }
    
    private func formatRate(_ bytesPerSecond: Int64) -> String {
        let bps = Double(bytesPerSecond * 8)
        switch bps {
        case 0..<1000:
            return "0 bps"
        case 1000..<1_000_000:
            return String(format: "%.0f Kbps", bps / 1000)
        case 1_000_000..<1_000_000_000:
            return String(format: "%.1f Mbps", bps / 1_000_000)
        default:
            return String(format: "%.1f Gbps", bps / 1_000_000_000)
        }
    }
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Add monitoring status item
        let statusMenuItem = NSMenuItem(title: monitor.isMonitoring ? "Monitoring Active" : "Monitoring Stopped", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Start/Stop item
        let monitorItem: NSMenuItem
        if monitor.isMonitoring {
            monitorItem = NSMenuItem(title: "Stop Monitoring", action: #selector(stopMonitoring), keyEquivalent: "")
        } else {
            monitorItem = NSMenuItem(title: "Start Monitoring", action: #selector(startMonitoring), keyEquivalent: "")
        }
        monitorItem.target = self
        menu.addItem(monitorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Preferences item
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add Quit item
        menu.addItem(NSMenuItem(title: "Quit Low Data", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    @objc private func togglePopover() {
        if let popover = popover {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    @objc private func startMonitoring() {
        monitor.startMonitoring()
    }
    
    @objc private func stopMonitoring() {
        monitor.stopMonitoring()
    }
    
    @objc private func openPreferences() {
        // Close popover if open
        if popover?.isShown == true {
            closePopover()
        }
        
        // Activate the app first to ensure menu bar is available
        NSApp.activate(ignoringOtherApps: true)
        
        // Use the Settings menu item directly
        Task { @MainActor in
            // Small delay to ensure activation completes
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Try to open Settings using the menu item
            if let appMenu = NSApp.mainMenu?.items.first?.submenu {
                for item in appMenu.items {
                    if item.title.contains("Settings") || item.title.contains("Preferences") {
                        NSApp.sendAction(item.action!, to: item.target, from: nil)
                        return
                    }
                }
            }
            
            // Fallback - open settings window directly
            if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
                settingsWindow.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func showPopover() {
        if let button = statusItem?.button {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    private func closePopover() {
        popover?.performClose(nil)
    }
    
    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}