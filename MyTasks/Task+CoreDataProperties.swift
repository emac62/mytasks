import Foundation
import CoreData

extension Task {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }
    @NSManaged public var createdOn: Date
    @NSManaged public var dueDate: Date?
    @NSManaged public var hasDueDate: Bool
    @NSManaged public var isComplete: Bool
    @NSManaged public var notes: String?
    @NSManaged public var title: String
}

extension Task: Identifiable {}
