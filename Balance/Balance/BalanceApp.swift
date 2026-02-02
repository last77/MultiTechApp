//
//  BalanceApp.swift
//  Balance
//
//  Created by app on 2026/2/2.
//

import SwiftUI
import CoreData

@main
struct BalanceApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
