import Foundation
import Combine
import AppKit

@MainActor
class TrafficMonitor: ObservableObject {
    @Published var processes: [ProcessTraffic] = []
    @Published var isMonitoring = false
    @Published var lastError: String?
    @Published var totalBytesIn: Int64 = 0
    @Published var totalBytesOut: Int64 = 0
    @Published var sessionStartTime: Date?
    @Published var totalSessionBytes: Int64 = 0
    @Published var totalRate: Int64 = 0  // bytes per second
    
    private var monitoringTask: Task<Void, Never>?
    private let commandRunner = CommandRunner.shared
    private var previousData: [Int: ProcessTraffic] = [:]
    private var baselineData: [Int: (bytesIn: Int64, bytesOut: Int64)] = [:]
    private var lastUpdateTime: Date?
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastError = nil
        sessionStartTime = Date()
        baselineData = [:]
        previousData = [:]
        lastUpdateTime = nil
        
        monitoringTask = Task {
            while isMonitoring {
                await updateTrafficData()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
        processes = []
        previousData = [:]
        baselineData = [:]
        totalBytesIn = 0
        totalBytesOut = 0
        totalSessionBytes = 0
        totalRate = 0
        sessionStartTime = nil
        lastUpdateTime = nil
    }
    
    func resetSession() {
        baselineData = [:]
        sessionStartTime = Date()
        for i in 0..<processes.count {
            processes[i].sessionBytesIn = 0
            processes[i].sessionBytesOut = 0
        }
        totalSessionBytes = 0
    }
    
    private func updateTrafficData() async {
        do {
            let trafficData = try await fetchNettopData()
            let currentTime = Date()
            let timeDelta = lastUpdateTime.map { currentTime.timeIntervalSince($0) } ?? 2.0
            
            var updatedProcesses: [ProcessTraffic] = []
            var newTotalRate: Int64 = 0
            var newSessionTotal: Int64 = 0
            
            for var process in trafficData {
                // Determine if this is an app
                process.isApp = isApplication(process.name)
                
                // Skip non-apps
                if !process.isApp { continue }
                
                // Try to find app path
                process.appPath = findAppPath(for: process.name)
                
                // Set up baseline for session tracking
                if baselineData[process.pid] == nil {
                    baselineData[process.pid] = (process.bytesIn, process.bytesOut)
                }
                
                // Calculate session bytes
                if let baseline = baselineData[process.pid] {
                    process.sessionBytesIn = max(0, process.bytesIn - baseline.bytesIn)
                    process.sessionBytesOut = max(0, process.bytesOut - baseline.bytesOut)
                }
                
                // Calculate rates
                if let previous = previousData[process.pid] {
                    let bytesInDelta = max(0, process.bytesIn - previous.bytesIn)
                    let bytesOutDelta = max(0, process.bytesOut - previous.bytesOut)
                    
                    process.bytesInRate = Int64(Double(bytesInDelta) / timeDelta)
                    process.bytesOutRate = Int64(Double(bytesOutDelta) / timeDelta)
                }
                
                newTotalRate += process.totalRate
                newSessionTotal += process.sessionTotalBytes
                updatedProcesses.append(process)
            }
            
            // Sort by session total bytes (biggest users first)
            processes = updatedProcesses.sorted { $0.sessionTotalBytes > $1.sessionTotalBytes }
            
            // Update totals
            totalBytesIn = processes.reduce(0) { $0 + $1.bytesIn }
            totalBytesOut = processes.reduce(0) { $0 + $1.bytesOut }
            totalSessionBytes = newSessionTotal
            totalRate = newTotalRate
            
            // Store current data for next rate calculation
            previousData = Dictionary(uniqueKeysWithValues: trafficData.map { ($0.pid, $0) })
            lastUpdateTime = currentTime
            
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            // Silently handle errors to avoid console spam
        }
    }
    
    private func isApplication(_ processName: String) -> Bool {
        // System processes to exclude (case-insensitive)
        let systemProcesses = Set([
            "kernel_task", "launchd", "syslogd", "mdnsresponder", "airportd",
            "cupsd", "symptomsd", "syspolicyd", "trustd", "nsurlsessiond",
            "homed", "replicatord", "coreaudiod", "windowserver", "loginwindow",
            "cfprefsd", "distnoted", "configd", "systemstats", "wirelessproxd",
            "bluetoothd", "powerd", "logd", "notifyd", "securityd", "locationd",
            "tccd", "timed", "corespotlightd", "mds", "mds_stores", "mdworker",
            "mdworker_shared", "fseventsd", "coreservicesd", "thermald",
            "runningboardd", "dasd", "networkserviceproxy", "nehelper",
            "dataaccessd", "apsd", "cloudd", "sharingd", "identityservicesd",
            "identityservice",
            "rapportd", "controlcenter", "commcenter", "netbiosd", "kdc",
            "networkd", "usbd", "deleted", "bird", "assistantd", "siriinferenced"
        ])
        
        let lowerName = processName.lowercased()
        
        // Check if it's a known system process
        if systemProcesses.contains(lowerName) {
            return false
        }
        
        // Check for common patterns of system processes
        if processName.hasPrefix("com.apple.") && 
           !processName.contains("WebKit") && 
           !processName.contains("Safari") {
            return false
        }
        
        // Exclude daemons and helpers unless they're from known apps
        if (lowerName.hasSuffix("d") || lowerName.contains("helper")) &&
           !lowerName.contains("chat") && 
           !lowerName.contains("claude") &&
           !lowerName.contains("zoom") &&
           !lowerName.contains("slack") &&
           !lowerName.contains("discord") {
            // Check if it's really an app helper
            if findAppPath(for: processName) == nil {
                return false
            }
        }
        
        return true
    }
    
    private func findAppPath(for processName: String) -> String? {
        // Special cases for known apps with different process names
        let knownMappings: [String: String] = [
            "ChatGPT": "ChatGPT",
            "ChatGPTHelper": "ChatGPT",
            "Claude Helper": "Claude",
            "Resilio Sync": "Resilio Sync",
            "syncthing": "Syncthing",
            "com.apple.WebKit.WebContent": "Safari",
            "com.apple.WebKit.Networking": "Safari"
        ]
        
        let appName = knownMappings[processName] ?? processName
        
        // Common app locations
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/Applications/Utilities",
            "/Applications/Setapp",
            "~/Applications",
            "~/Applications/Setapp"
        ]
        
        let fileManager = FileManager.default
        
        for searchPath in searchPaths {
            let expandedPath = NSString(string: searchPath).expandingTildeInPath
            
            // Try exact match first
            let appPath = "\(expandedPath)/\(appName).app"
            if fileManager.fileExists(atPath: appPath) {
                return appPath
            }
            
            // Try some common variations
            let variations = [
                appName.replacingOccurrences(of: " ", with: ""),
                appName.replacingOccurrences(of: "-", with: " "),
                appName.replacingOccurrences(of: "Helper", with: ""),
                appName.replacingOccurrences(of: "helper", with: ""),
                appName.capitalized,
                appName.lowercased(),
                appName.uppercased()
            ]
            
            for variation in Set(variations) where !variation.isEmpty {
                let variantPath = "\(expandedPath)/\(variation).app"
                if fileManager.fileExists(atPath: variantPath) {
                    return variantPath
                }
            }
        }
        
        // Try to find by bundle identifier using NSWorkspace
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: "com.\(appName.lowercased())") {
            return appURL.path
        }
        
        return nil
    }
    
    private func fetchNettopData() async throws -> [ProcessTraffic] {
        do {
            let output = try await commandRunner.executeWithTimeout(
                "nettop -P -L 1 -J bytes_in,bytes_out",
                timeout: 3.0
            )
            
            return parseNettopOutput(output)
        } catch {
            // Silently fall back to lsof
            return []
        }
    }
    
    private func parseNettopOutput(_ output: String) -> [ProcessTraffic] {
        var result: [ProcessTraffic] = []
        let lines = output.components(separatedBy: .newlines)
        
        guard lines.count > 1 else { return [] }
        
        for line in lines.dropFirst() where !line.isEmpty {
            let components = line.components(separatedBy: ",")
            guard components.count >= 3 else { continue }
            
            // First component is "processname.pid", need to split it
            let processInfo = components[0].trimmingCharacters(in: .whitespaces)
            let lastDotIndex = processInfo.lastIndex(of: ".") ?? processInfo.endIndex
            let processName = String(processInfo[..<lastDotIndex])
            let pidString = String(processInfo[processInfo.index(after: lastDotIndex)...])
            
            guard let pid = Int(pidString),
                  let bytesIn = Int64(components[1].trimmingCharacters(in: .whitespaces)),
                  let bytesOut = Int64(components[2].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            
            let traffic = ProcessTraffic(
                name: processName.isEmpty ? "Unknown" : processName,
                pid: pid,
                bytesIn: bytesIn,
                bytesOut: bytesOut,
                connectionsCount: 0,
                timestamp: Date()
            )
            
            result.append(traffic)
        }
        
        return result
    }
    
    private func fetchLsofData() async throws -> [ProcessTraffic] {
        let output = try await commandRunner.executeWithTimeout(
            "lsof -i -n -P",
            timeout: 3.0
        )
        
        return parseLsofOutput(output)
    }
    
    private func parseLsofOutput(_ output: String) -> [ProcessTraffic] {
        var processMap: [Int: (name: String, count: Int)] = [:]
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines.dropFirst() where !line.isEmpty {
            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count >= 2 else { continue }
            
            let processName = components[0]
            guard let pid = Int(components[1]) else { continue }
            
            if let existing = processMap[pid] {
                processMap[pid] = (existing.name, existing.count + 1)
            } else {
                processMap[pid] = (processName, 1)
            }
        }
        
        return processMap.map { pid, data in
            ProcessTraffic(
                name: data.name,
                pid: pid,
                bytesIn: 0,
                bytesOut: 0,
                connectionsCount: data.count,
                timestamp: Date()
            )
        }
    }
}