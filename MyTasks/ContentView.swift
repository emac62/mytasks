//
//  ContentView.swift
//  MyTasks
//
//  Created by Ellen McConomy on 2026-01-07.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var refreshID = UUID()
    @State private var showDeleteAllConfirmation = false
    @State private var selectedFilter: TaskFilter = .all
    @State private var showFilterSheet = false
    @State private var isEditing = false

    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "Show All"
        case overdue = "Overdue"
        case today = "Due Today"
        case future = "Future"
        case noDueDate = "No Due Date"
        var id: String { rawValue }
    }

    private var filteredItems: [Task] {
        let today = Calendar.current.startOfDay(for: Date())
        switch selectedFilter {
        case .all:
            return Array(items)
        case .overdue:
            return items.filter { task in
                if let due = task.dueDate {
                    return due < today && !task.isComplete
                }
                return false
            }
        case .today:
            return items.filter { task in
                if let due = task.dueDate {
                    return Calendar.current.isDate(due, inSameDayAs: today)
                }
                return false
            }
        case .future:
            return items.filter { task in
                if let due = task.dueDate {
                    return due > today
                }
                return false
            }
        case .noDueDate:
            return items.filter { $0.dueDate == nil }
        }
    }

    @FetchRequest(
        fetchRequest: {
            let request = Task.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Task.createdOn, ascending: true)]
            return request
        }())
    private var items: FetchedResults<Task>

    var body: some View {
            
        NavigationView {
            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    HStack(spacing: 16) {
                        Button(action: { showDeleteAllConfirmation = true }) {
                            Label("", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                        Button(action: { isEditing.toggle() }) {
                            Text(isEditing ? "Done" : "Edit")
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { showFilterSheet = true }) {
                            Text("Filter")
                                .foregroundColor(.red)
                        }
                        NavigationLink(destination: TaskDetailView()) {
                            Image(systemName: "plus")
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Text("My Tasks")
                    .font(.custom("MarkerFelt-Wide", size: 36))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading)
                    .padding(.bottom, 8)
                   
                List {
                    ForEach(filteredItems) { item in
                        HStack {
                            Button(action: { toggleComplete(for: item) }) {
                                Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isComplete ? .accentColor : .secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(PlainButtonStyle())
                            NavigationLink {
                                TaskDetailView(task: item)
                            } label: {
                                item.isComplete ? Text(item.title)
                                    .strikethrough()
                                    .foregroundColor(.secondary)
                                :
                                Text(item.title)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .id(refreshID)
                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
            }
            .background(Color(.systemBackground))
            .confirmationDialog("Are you sure you want to delete all tasks?", isPresented: $showDeleteAllConfirmation, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    deleteAllTasks()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showFilterSheet) {
                VStack(spacing: 24) {
                    Text("Filter Options")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    ForEach(TaskFilter.allCases) { filter in
                        Button(action: {
                            selectedFilter = filter
                            showFilterSheet = false
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                    .font(.title3)
                                    .foregroundColor(selectedFilter == filter ? .red : .primary)
                                Text("(\(taskCount(for: filter)))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.horizontal)
                    }
                    Spacer()
                    Button(action: { showFilterSheet = false }) {
                        Text("Cancel")
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }


    private func deleteItems(offsets: IndexSet) {
        print("deleteItems called with offsets: \(offsets)")
        withAnimation {
            offsets.map { items[$0] }.forEach { item in
                print("Deleting task: \(item.title)")
                viewContext.delete(item)
            }
            do {
                try viewContext.save()
                print("Context saved after deletion.")
            } catch {
                let nsError = error as NSError
                print("Error deleting items: \(nsError), \(nsError.userInfo)")
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteAllTasks() {
        print("deleteAllTasks called. Tasks before delete: \(items.count)")
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        do {
            let allTasks = try viewContext.fetch(fetchRequest)
            print("Fetched \(allTasks.count) tasks for deletion.")
            for task in allTasks {
                viewContext.delete(task)
            }
            try viewContext.save()
            print("All tasks deleted. Tasks after delete: \(items.count)")
            refreshID = UUID() // Force List to refresh
        } catch {
            let nsError = error as NSError
            print("Error deleting all tasks: \(nsError), \(nsError.userInfo)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func toggleComplete(for item: Task) {
        withAnimation {
            item.isComplete.toggle()
            print("Toggled isComplete for \(item.title) to \(item.isComplete)")
            do {
                try viewContext.save()
                refreshID = UUID() // Force List to refresh after toggle
            } catch {
                let nsError = error as NSError
                print("Error saving isComplete toggle: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    private func taskCount(for filter: TaskFilter) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: today)!
        switch filter {
        case .all:
            return items.count
        case .overdue:
            return items.filter { task in
                if let due = task.dueDate {
                    return due < today && !task.isComplete
                }
                return false
            }.count
        case .today:
            return items.filter { task in
                if let due = task.dueDate {
                    return Calendar.current.isDate(due, inSameDayAs: today)
                }
                return false
            }.count
        case .future:
            return items.filter { task in
                if let due = task.dueDate {
                    return due >= tomorrow && due < dayAfterTomorrow
                }
                return false
            }.count
        case .noDueDate:
            return items.filter { $0.dueDate == nil }.count
        }
    }
}
