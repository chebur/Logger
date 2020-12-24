//
//  PersistentHistoryTracker.swift
//
//
//  Created by Dmitry Nesterenko on 11.09.2020.
//

import CoreData
#if os(iOS)
import class UIKit.UIApplication
#endif

/// Tracks and merges remote store changes
///
/// See
/// [Consuming Relevant Store Changes](https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes)
/// [Persistent History Tracking in Core Data](https://www.avanderlee.com/swift/persistent-history-tracking-core-data/)
@available(iOS 11.0, OSX 10.13, *)
final class PersistentHistoryTracker {
    let container: NSPersistentContainer
    
    /// Used to filter persistent history transactions
    ///
    /// Example:
    /// ```
    /// NSPredicate(format: "%K != %@", #keyPath(NSPersistentHistoryTransaction.bundleID), bundleIdentifier)
    /// ```
    var predicate: NSPredicate?
    
    /// An operation queue for processing history transactions.
    private let queue: OperationQueue = {
        $0.maxConcurrentOperationCount = 1
        $0.qualityOfService = .userInitiated
        return $0
    }(OperationQueue())
    
    /// Background context which is proccessing history changes
    private let context: NSManagedObjectContext
    
    /// Last history change transaction token
    private var token: NSPersistentHistoryToken?
    
    /// - Parameters:
    ///     - container: A container that encapsulates the Core Data stack.
    init(container: NSPersistentContainer) {
        self.container = container
        self.context = container.newBackgroundContext()
        
        if #available(iOS 12.0, *) {
            token = container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: container.persistentStoreCoordinator.persistentStores)
        }
    }
    
    func setObservationEnabled(_ enabled: Bool) {
        if #available(iOS 12.0, *) {
            // implement persistent store changes using remote change notification
            setPersistentStoreRemoteChangeNotificationObservationEnabled(enabled)
        } else {
            // implement persistent store changes using polling on application did become active notification
            setApplicationDidBecomeActiveNotificationObservationEnabled(enabled)
        }
    }
    
    // MARK: Managing Persistent Store Change Notifications
    
    @available(iOS 12, OSX 10.14, *)
    private func setPersistentStoreRemoteChangeNotificationObservationEnabled(_ enabled: Bool) {
        if enabled {
            NotificationCenter.default.addObserver(self, selector: #selector(persistentStoreDidReceiveRemoteChangeNotification(_:)), name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
        } else {
            NotificationCenter.default.removeObserver(self, name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
        }
    }
    
    @objc
    private func persistentStoreDidReceiveRemoteChangeNotification(_ notification: NSNotification) {
        handlePersistentStoreHistoryChanges()
    }
    
    @available(iOS, obsoleted: 12, message: "Switch to persistent store remote change notification")
    private func setApplicationDidBecomeActiveNotificationObservationEnabled(_ enabled: Bool) {
        if enabled {
            NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActiveNotification(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        } else {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        }
    }

    @objc
    @available(iOS, obsoleted: 12, message: "Switch to persistent store remote change notification")
    private func applicationDidBecomeActiveNotification(_ notification: NSNotification) {
        handlePersistentStoreHistoryChanges()
    }
    
    // MARK: Merging Persistent Store Changes
    
    private func handlePersistentStoreHistoryChanges() {
        let context = self.context
        
        queue.addOperation { [weak self] in
            // syncronously handle persistent store change on a background context
            context.performAndWait {
                let result = self?.mergePersistentHistoryChanges(after: self?.token, in: context)
                if let token = try? result?.get() {
                    self?.token = token
                    self?.deletePersistentHistoryChanges(before: token, in: context)
                }
            }
        }
    }
    
    @discardableResult
    private func mergePersistentHistoryChanges(after token: NSPersistentHistoryToken?, in context: NSManagedObjectContext) -> Result<NSPersistentHistoryToken, Error>? {
        do {
            // configure fetch transactions request and filter by predicate when running on iOS 13+
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
            if #available(iOS 13.0, *), let fetchRequest = NSPersistentHistoryTransaction.fetchRequest, let predicate = predicate {
                fetchRequest.predicate = predicate
                request.fetchRequest = fetchRequest
            }
            
            // execute fetch transactions request and filter results when running on iOS <13
            let result = try context.execute(request) as? NSPersistentHistoryResult
            var transactions = result?.result as? [NSPersistentHistoryTransaction]
            if #available(iOS 13, *), request.fetchRequest != nil {
                // results already has been filtered by fetch request predicate condition
            } else if let predicate = predicate {
                transactions = transactions?.filter { predicate.evaluate(with: $0) }
            }

            for transaction in transactions ?? [] {
                // merge changes from transaction to view context
                container.viewContext.performAndWait {
                    container.viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                }
            }
            let token = transactions?.last?.token
            return token.flatMap { .success($0) }
        } catch {
            return .failure(error)
        }
    }
    
    @discardableResult
    private func deletePersistentHistoryChanges(before token: NSPersistentHistoryToken, in context: NSManagedObjectContext) -> Result<NSPersistentStoreResult, Error> {
        let request = NSPersistentHistoryChangeRequest.deleteHistory(before: token)
        return Result {
            try context.execute(request)
        }
    }
}
