//
//  FetchedResultsControllerHandler.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 21.08.2020.
//

import Foundation
import CoreData

#if os(iOS)
import struct UIKit.NSDiffableDataSourceSnapshot
import class UIKit.NSDiffableDataSourceSnapshotReference

/// Notifies the receiver about changes to the content in the fetched results controller, by using a diffable data source snapshot.
@available(iOS 13, *)
final class FetchedResultsControllerSnapshotHandler<SectionIdentifierType: Hashable, ItemIdentifierType: Hashable>: NSObject, NSFetchedResultsControllerDelegate {
    var didChangeContentWithSnapshot: ((NSFetchedResultsController<NSFetchRequestResult>, NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>) -> Void)?
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        didChangeContentWithSnapshot?(controller, snapshot as NSDiffableDataSourceSnapshot<SectionIdentifierType, ItemIdentifierType>)
    }
}

/// Notifies the receiver about changes to the content in the fetched results controller, by using a collection difference.
@available(iOS 13, *)
final class FetchedResultsControllerDiffHandler: NSObject, NSFetchedResultsControllerDelegate {
    var didChangeContentWithDiff: ((NSFetchedResultsController<NSFetchRequestResult>, CollectionDifference<NSManagedObjectID>) -> Void)?
    
    /// This method is only invoked if the controller’s sectionNameKeyPath property is nil
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        didChangeContentWithDiff?(controller, diff)
    }
}
#endif

/// Notifies the receiver that the fetched results controller has completed processing of one or more changes due to an add, remove, move, or update.
final class FetchedResultsControllerHandler: NSObject, NSFetchedResultsControllerDelegate {
    var didChangeContent: ((NSFetchedResultsController<NSFetchRequestResult>) -> Void)?
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        didChangeContent?(controller)
    }
}
