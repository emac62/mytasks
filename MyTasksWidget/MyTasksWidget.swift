//
//  MyTasksWidget.swift
//  MyTasksWidget
//
//  Created by Ellen McConomy on 2026-01-12.
//

import WidgetKit
import SwiftUI
import CoreData

struct TaskWidgetModel: Identifiable {
    let id = UUID()
    let title: String
    let dueDate: Date?
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let todaysTasks: [TaskWidgetModel]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), todaysTasks: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let tasks = fetchOverdueAndTodayTasks()
        completion(SimpleEntry(date: Date(), todaysTasks: tasks))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entryDate = Date()
        let tasks = fetchOverdueAndTodayTasks()
        let entry = SimpleEntry(date: entryDate, todaysTasks: tasks)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
    
    private func fetchOverdueAndTodayTasks() -> [TaskWidgetModel] {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.ellen.MyTasks") else {
            print("[Widget] Could not get App Group container URL")
            return []
        }
        let storeURL = containerURL.appendingPathComponent("MyTasks.sqlite")
        print("[Widget] Core Data store URL: \(storeURL.path)")
        let description = NSPersistentStoreDescription(url: storeURL)
        let container = NSPersistentContainer(name: "MyTasks")
        container.persistentStoreDescriptions = [description]
        var result: [TaskWidgetModel] = []
        let semaphore = DispatchSemaphore(value: 0)
        container.loadPersistentStores { _, error in
            defer { semaphore.signal() }
            if let error = error {
                print("[Widget] Core Data error: \(error)")
                return
            }
            let context = container.viewContext
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Task")
            // Build date range for end of today
            let calendar = Calendar.current
            let now = Date()
            guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
                print("[Widget] Could not calculate startOfTomorrow")
                return
            }
            let dueDatePredicate = NSPredicate(format: "dueDate < %@", startOfTomorrow as NSDate)
            let isCompletePredicate = NSPredicate(format: "isComplete == NO")
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dueDatePredicate, isCompletePredicate])
            fetchRequest.predicate = compoundPredicate
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
            do {
                let tasks = try context.fetch(fetchRequest)
                print("[Widget] Number of tasks fetched: \(tasks.count)")
                for task in tasks {
                    if let title = task.value(forKey: "title") as? String,
                       let dueDate = task.value(forKey: "dueDate") as? Date {
                        result.append(TaskWidgetModel(title: title, dueDate: dueDate))
                    }
                }
                if tasks.isEmpty {
                    print("[Widget] No tasks found for today or overdue.")
                }
            } catch {
                print("[Widget] Fetch error: \(error)")
            }
        }
        semaphore.wait()
        return result
    }
}

struct MyTasksWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image("Today Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                Text("Today's Tasks")
                    .font(.custom("MarkerFelt-Wide", size: 24))
                    .fontWeight(.bold)
            }
            .padding(.bottom, 4)
            Divider()
                .background(Color.secondary)
                .padding(.bottom, 4)
            if entry.todaysTasks.isEmpty {
                Text("No tasks due today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                ForEach(entry.todaysTasks) { task in
                    let isOverdue = task.dueDate! < today
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(isOverdue ? .red : .primary)
                        Text(task.title)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundColor(isOverdue ? .red : .primary)
                    }
                }
            }
        }
        .padding()
    }
}

struct MyTasksWidget: Widget {
    let kind: String = "MyTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MyTasksWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
