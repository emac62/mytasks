import SwiftUI
import CoreData
import WidgetKit
import UserNotifications

struct TaskDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Optional task for edit mode
    let task: Task?
    let isNew: Bool

    // State for add mode
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var isComplete: Bool = false
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    // For edit mode
    @ObservedObject private var observedTask: Task

    // Single initializer
    init(task: Task? = nil) {
        self.task = task
        self.isNew = (task == nil)
        if let task = task {
            _observedTask = ObservedObject(wrappedValue: task)
            _title = State(initialValue: task.title)
            _notes = State(initialValue: task.notes ?? "")
            _isComplete = State(initialValue: task.isComplete)
            _hasDueDate = State(initialValue: task.hasDueDate)
            _dueDate = State(initialValue: task.dueDate ?? Date())
        } else {
            // Dummy for add mode, not used
            _observedTask = ObservedObject(wrappedValue: Task(context: NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .font(.body)
                }
                Spacer()
                Button(action: { saveTask() }) {
                    Text(isNew ? "Save" : "Update")
                        .foregroundColor(.red)
                        .font(.body)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            // Title
            Text(isNew ? "New Task" : "Edit Task")
                .font(.custom("MarkerFelt-Wide", size: 28))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading)
                .padding(.bottom, 8)
            // Form
            Form {
                Section(header: Text("Task Details")) {
                    if isNew {
                        TextField("Title", text: $title)
                            .font(.system( size: 24))
                            .foregroundColor(.accentColor)
                            .fontWeight(.bold)
                    } else {
                        TextField("Title", text: $observedTask.title)
                            .font(.system( size: 24))
                            .foregroundColor(.accentColor)
                            .fontWeight(.bold)
                    }
                    Toggle("Set Due Date", isOn: isNew ? $hasDueDate : $observedTask.hasDueDate)
                        .tint(.accentColor)
                    if (isNew ? hasDueDate : observedTask.hasDueDate) {
                        DatePicker("Due Date", selection: isNew ? $dueDate : Binding(
                            get: { observedTask.dueDate ?? Date() },
                            set: { observedTask.dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                    Text("Notes")
                    if isNew {
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    } else {
                        TextEditor(text: Binding(
                            get: { observedTask.notes ?? "" },
                            set: { observedTask.notes = $0.isEmpty ? nil : $0 }
                        ))
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
            }
            // Delete Button
            if !isNew {
                Button(action: { showDeleteConfirmation = true }) {
                    Text("Delete Task")
                        .font(.title3)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding()
                .confirmationDialog("Are you sure you want to delete this task?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        deleteTask()
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
    }

    private func saveTask() {
        if isNew {
            let newTask = Task(context: viewContext)
            newTask.title = title
            newTask.notes = notes.isEmpty ? nil : notes
            newTask.isComplete = isComplete
            newTask.hasDueDate = hasDueDate
            newTask.dueDate = hasDueDate ? dueDate : nil
            if !hasDueDate { newTask.dueDate = nil }
            newTask.createdOn = Date()
            do {
                try viewContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                updateAppBadge()
                scheduleMidnightBadgeUpdate()
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        } else {
            // Keep hasDueDate and dueDate in sync
            if !observedTask.hasDueDate {
                observedTask.dueDate = nil
            } else if observedTask.dueDate == nil {
                observedTask.dueDate = Date()
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            dateFormatter.timeZone = TimeZone.current
            let dueDateString = observedTask.dueDate != nil ? dateFormatter.string(from: observedTask.dueDate!) : "nil"
            print("[Edit] Saving task: title=\(observedTask.title), notes=\(observedTask.notes ?? "nil"), isComplete=\(observedTask.isComplete), hasDueDate=\(observedTask.hasDueDate), dueDate=\(dueDateString)")
            do {
                try viewContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                updateAppBadge()
                scheduleMidnightBadgeUpdate()
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        }
    }

    @State private var showDeleteConfirmation = false

    private func deleteTask() {
        viewContext.delete(observedTask)
        do {
            try viewContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            updateAppBadge()
            scheduleMidnightBadgeUpdate()
            dismiss()
        } catch {
            print("Error deleting task: \(error)")
        }
    }

    private func updateAppBadge() {
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.sortDescriptors = []
        do {
            let allTasks = try viewContext.fetch(fetchRequest)
            let today = Calendar.current.startOfDay(for: Date())
            print("[Debug] All tasks (", allTasks.count, "):")
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            dateFormatter.timeZone = TimeZone.current
            for task in allTasks {
                let dueString = task.dueDate != nil ? dateFormatter.string(from: task.dueDate!) : "nil"
                print("- \(task.title), due: \(dueString), isComplete: \(task.isComplete), hasDueDate: \(task.hasDueDate)")
            }
            let overdueCount = allTasks.filter { task in
                if let due = task.dueDate {
                    return due < today && !task.isComplete
                }
                return false
            }.count
            let todayCount = allTasks.filter { task in
                if let due = task.dueDate {
                    return Calendar.current.isDate(due, inSameDayAs: today) && !task.isComplete
                }
                return false
            }.count
            let badgeCount = overdueCount + todayCount
            print("[Debug] overdueCount: \(overdueCount), todayCount: \(todayCount), badgeCount: \(badgeCount)")
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(badgeCount)
                print("[Badge] Set app icon badge to \(badgeCount) using UNUserNotificationCenter (iOS 17+)")
            } else {
                DispatchQueue.main.async {
                    UIApplication.shared.applicationIconBadgeNumber = badgeCount
                    print("[Badge] Set app icon badge to \(badgeCount) using UIApplication (pre-iOS 17)")
                }
            }
        } catch {
            print("[Badge] Error fetching tasks for badge: \(error)")
        }
    }

    private func scheduleMidnightBadgeUpdate() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["MidnightBadgeUpdate"])
        let calendar = Calendar.current
        let now = Date()
        guard let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) else {
            print("[Badge] Could not calculate next midnight.")
            return
        }
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.sortDescriptors = []
        do {
            let allTasks = try viewContext.fetch(fetchRequest)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            let overdueCount = allTasks.filter { task in
                if let due = task.dueDate {
                    return due < tomorrow && !task.isComplete
                }
                return false
            }.count
            let todayCount = allTasks.filter { task in
                if let due = task.dueDate {
                    return calendar.isDate(due, inSameDayAs: tomorrow) && !task.isComplete
                }
                return false
            }.count
            let badgeCount = overdueCount + todayCount
            let content = UNMutableNotificationContent()
            content.badge = NSNumber(value: badgeCount)
            content.sound = nil
            content.body = ""
            content.title = ""
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nextMidnight), repeats: false)
            let request = UNNotificationRequest(identifier: "MidnightBadgeUpdate", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Badge] Error scheduling midnight badge update: \(error)")
                } else {
                    print("[Badge] Scheduled badge update at midnight with badge count: \(badgeCount)")
                }
            }
        } catch {
            print("[Badge] Error fetching tasks for midnight badge update: \(error)")
        }
    }
}
