//
//  LowDataApp.swift
//  LowData
//
//  Created by Konrad Michels on 8/31/25.
//

import SwiftUI

@main
struct LowDataApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
