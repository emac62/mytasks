//
//  MyTasksApp.swift
//  MyTasks
//
//  Created by Ellen McConomy on 2026-01-07.
//

import SwiftUI
import CoreData
import UserNotifications

@main
struct MyTasksApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        // Request notification authorization for badge updates
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            } else {
                print("Notification authorization granted: \(granted)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .accentColor(.red)
        }
    }
}
