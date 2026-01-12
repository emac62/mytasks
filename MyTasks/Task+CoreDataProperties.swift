//
//  Task+CoreDataProperties.swift
//  MyTasks
//
//  Created by Ellen McConomy on 2026-01-07.
//
//

public import Foundation
public import CoreData


public typealias TaskCoreDataPropertiesSet = NSSet

extension Task {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Task> {
        return NSFetchRequest<Task>(entityName: "Task")
    }

    @NSManaged public var title: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdOn: Date?
    @NSManaged public var dueDate: Date?
    @NSManaged public var isComplete: Bool
    @NSManaged public var hasDueDate: Bool

}

extension Task : Identifiable {

}
