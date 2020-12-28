//
//  NSManagedObjectContext+Extension.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 21.08.2020.
//

import Foundation
import CoreData

#if os(iOS)
import struct UIKit.NSDiffableDataSourceSnapshot

public extension NSManagedObjectContext {
    /// Notifies the receiver about changes to the content in the fetched results controller, by using a diffable data source snapshot.
    @available(iOS 13, *)
    func observe<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, sectionNameKeyPath: String? = nil, cacheName: String? = nil, didChangeContentWithSnapshot: @escaping (NSDiffableDataSourceSnapshot<NSManagedObjectID, T>) -> Void) throws -> FetchedResultsObservation {
        let handler = FetchedResultsControllerSnapshotHandler<NSManagedObjectID, T>()
        handler.didChangeContentWithSnapshot = { controller, snapshot in
            didChangeContentWithSnapshot(snapshot)
        }
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        frc.delegate = handler
        try frc.performFetch()
        
        return FetchedResultsObservation(frc: frc, handler: handler)
    }
}
#endif

public extension NSManagedObjectContext {
    /// Notifies the receiver about changes to the content in the fetched results controller, by using a collection difference.
    @available(iOS 13, OSX 10.15, *)
    func observe<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, sectionNameKeyPath: String? = nil, cacheName: String? = nil, didChangeContentWithDiff: @escaping (CollectionDifference<NSManagedObjectID>) -> Void) throws -> FetchedResultsObservation {
        let handler = FetchedResultsControllerDiffHandler()
        handler.didChangeContentWithDiff = { controller, diff in
            didChangeContentWithDiff(diff)
        }
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        frc.delegate = handler
        try frc.performFetch()
        
        return FetchedResultsObservation(frc: frc, handler: handler)
    }
    
    /// Notifies the receiver that the fetched results controller has completed processing of one or more changes due to an add, remove, move, or update.
    func observe<T: NSFetchRequestResult>(fetchRequest: NSFetchRequest<T>, sectionNameKeyPath: String? = nil, cacheName: String? = nil, didChangeContent: @escaping ([T]) -> Void) throws -> FetchedResultsObservation {
        let handler = FetchedResultsControllerHandler()
        handler.didChangeContent = { controller in
            // The value of the property is nil if performFetch() hasn’t been called.
            let fetchedObjects = controller.fetchedObjects as? [T]
            didChangeContent(fetchedObjects ?? [])
        }
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName)
        frc.delegate = handler
        try frc.performFetch()
        
        return FetchedResultsObservation(frc: frc, handler: handler)
    }
    
    /// Executes batch delete request with the given `NSFetchRequest` and directly merges the changes to bring the given managed object context up to date.
    ///
    /// [Implementing Batch Deletes](https://developer.apple.com/library/archive/featuredarticles/CoreData_Batch_Guide/BatchDeletes/BatchDeletes.html)
    ///
    /// - Parameters:
    ///     - fetchRequest: The `NSBatchDeleteRequest` to execute.
    ///     - contexts: Changes will be propagated to specified contexts.
    /// - Throws: An error if anything went wrong executing the batch deletion.
    func executeBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>, mergeChangesInto contexts: [NSManagedObjectContext]) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        let result = try execute(deleteRequest) as? NSBatchDeleteResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: contexts)
        }
    }
}
