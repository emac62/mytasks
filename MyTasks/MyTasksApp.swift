//
//  MyTasksApp.swift
//  MyTasks
//
//  Created by Ellen McConomy on 2026-01-07.
//

import SwiftUI
import CoreData

@main
struct MyTasksApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .accentColor(.red)
        }
    }
}
