//
//  ContentView.swift
//  LowData
//
//  Created by Konrad Michels on 8/31/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var extensionManager = ExtensionManager()
    @State private var lastUpdate = Date()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Low Data Network Monitor")
                .font(.largeTitle)
                .padding(.top)
            
            // Status Section
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Circle()
                            .fill(extensionManager.isFilterRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        Text(extensionManager.isFilterRunning ? "Filter Active" : "Filter Inactive")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack {
                        Text("Status:")
                            .foregroundColor(.secondary)
                        Text(extensionManager.status)
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Extension Status", systemImage: "shield")
            }
            
            // Statistics Section
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "network")
                            .foregroundColor(.blue)
                        Text("Flows Monitored:")
                        Spacer()
                        Text("\(extensionManager.flowCount)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    
                    if !extensionManager.lastAppIdentifier.isEmpty {
                        HStack {
                            Image(systemName: "app")
                                .foregroundColor(.blue)
                            Text("Last App:")
                            Spacer()
                            Text(extensionManager.lastAppIdentifier.components(separatedBy: ".").last ?? extensionManager.lastAppIdentifier)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                Label("Network Activity", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    extensionManager.installSystemExtension()
                }) {
                    Label("Install Extension", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(extensionManager.status == "Installed")
                
                Button(action: {
                    Task {
                        do {
                            if extensionManager.isFilterRunning {
                                try await extensionManager.deactivateFilter()
                            } else {
                                try await extensionManager.activateFilter()
                            }
                        } catch {
                            print("Filter toggle failed: \(error)")
                        }
                    }
                }) {
                    Label(extensionManager.isFilterRunning ? "Stop Filter" : "Start Filter", 
                          systemImage: extensionManager.isFilterRunning ? "stop.circle" : "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!extensionManager.status.contains("Installed"))
            }
            
            Spacer()
            
            // Footer info
            Text("Monitor network connections in real-time")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

#Preview {
    ContentView()
}
