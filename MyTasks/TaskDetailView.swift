import SwiftUI
import CoreData

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
            newTask.createdOn = Date()
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error saving task: \(error)")
            }
        } else {
            do {
                try viewContext.save()
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
            dismiss()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
}
