//
//  MessagesStorage.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 21.08.2020.
//

import Foundation
import CoreData
import Logging

public class MessagesStorage {
    public struct Message: Hashable {
        private let managedObjectId: URL
        public let label: String
        public let level: Logger.Level
        public let message: String
        public let metadata: Logger.Metadata?
        public let source: String
        public let file: String
        public let function: String
        public let line: UInt
        public let date: Date
        
        fileprivate init(entity: Entity) {
            managedObjectId = entity.objectID.uriRepresentation()
            label = entity.label
            level = Logger.Level(rawValue: entity.level) ?? .debug
            message = entity.message
            metadata = entity.metadata.flatMap { try? JSONDecoder().decode(Logger.Metadata.self, from: $0) }
            source = entity.source
            file = entity.file
            function = entity.function
            line = UInt(entity.line.int64Value)
            date = entity.date
        }
    }
    
    @objc(MessagesStorageEntity)
    fileprivate class Entity: NSManagedObject {
        @NSManaged var label: String
        @NSManaged var level: String
        @NSManaged var message: String
        @NSManaged var metadata: Data?
        @NSManaged var metadataNormalized: String? // used for text search
        @NSManaged var source: String
        @NSManaged var file: String
        @NSManaged var function: String
        @NSManaged var line: NSNumber
        @NSManaged var date: Date
    }
    
    private let container: NSPersistentContainer
    
    private static let managedObjectModel: NSManagedObjectModel = {
        let label = NSAttributeDescription()
        label.attributeType = .stringAttributeType
        label.name = #keyPath(Entity.label)
        label.isOptional = false
        
        let level = NSAttributeDescription()
        level.attributeType = .stringAttributeType
        level.name = #keyPath(Entity.level)
        level.isOptional = false
        
        let message = NSAttributeDescription()
        message.attributeType = .stringAttributeType
        message.name = #keyPath(Entity.message)
        message.isOptional = false

        let metadata = NSAttributeDescription()
        metadata.attributeType = .binaryDataAttributeType
        metadata.name = #keyPath(Entity.metadata)
        metadata.isOptional = true
        
        let metadataNormalized = NSAttributeDescription()
        metadataNormalized.attributeType = .stringAttributeType
        metadataNormalized.name = #keyPath(Entity.metadataNormalized)
        metadataNormalized.isOptional = true
        
        let source = NSAttributeDescription()
        source.attributeType = .stringAttributeType
        source.name = #keyPath(Entity.source)
        source.isOptional = false
        
        let file = NSAttributeDescription()
        file.attributeType = .stringAttributeType
        file.name = #keyPath(Entity.file)
        file.isOptional = false

        let function = NSAttributeDescription()
        function.attributeType = .stringAttributeType
        function.name = #keyPath(Entity.function)
        function.isOptional = false
        
        let line = NSAttributeDescription()
        line.attributeType = .integer64AttributeType
        line.name = #keyPath(Entity.line)
        line.isOptional = false
        
        let date = NSAttributeDescription()
        date.attributeType = .dateAttributeType
        date.name = #keyPath(Entity.date)
        date.isOptional = false
        
        let entityName = NSStringFromClass(Entity.self)
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = entityName
        entity.properties = [label, level, message, metadata, metadataNormalized, source, file, function, line, date]
            
        if #available(iOS 11, *) {
            let dateIndexElement = NSFetchIndexElementDescription(property: date, collationType: .binary)
            dateIndexElement.isAscending = false
            let byDate = NSFetchIndexDescription(name: "byDate", elements: [dateIndexElement])
            
            entity.indexes = [byDate]
        }

        let model = NSManagedObjectModel()
        model.entities = [entity]
        
        return model
    }()
    
    private let backgroundContext: NSManagedObjectContext
    private var tracker: Any?
    
    /// Initializes the receiver with a store name.
    ///
    /// The sqlite file will be created in the library directory of the user domain.
    ///
    /// - Parameters:
    ///     - name: The name of the sqlite file for pesistent storage.
    public convenience init(name: String, completionHandler: ((NSPersistentStoreDescription, Error?) -> Void)? = nil) throws {
        var logsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true) ?? URL(fileURLWithPath: "/dev/null")

        // ignore Logs directory from backups
        if !FileManager.default.fileExists(atPath: logsURL.path) {
            try FileManager.default.createDirectory(at: logsURL, withIntermediateDirectories: true, attributes: [:])
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try logsURL.setResourceValues(resourceValues)
        }

        let storeURL = logsURL.appendingPathComponent("\(name).sqlite", isDirectory: false)
        self.init(url: storeURL, completionHandler: completionHandler)
    }
    
    /// Initializes the receiver with a URL for the store.
    ///
    /// - parameters:
    ///     - url: Location for the store.
    ///     - completionHandler: The completion handler is called once when the persistent store finished loading.
    ///
    /// - warning: Make sure the directory used in storeURL exists.
    public init(url: URL, completionHandler: ((NSPersistentStoreDescription, Error?) -> Void)? = nil) {
        let name = String(describing: CoreDataLogHandler.self)
        container = NSPersistentContainer(name: name, managedObjectModel: Self.managedObjectModel)
        let description = NSPersistentStoreDescription(url: url)
        if #available(iOS 11.0, *) {
            // turn on persistent history tracking
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            if #available(iOS 13.0, *) {
                // turn on remote change notifications
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            } else {
                description.setOption(true as NSNumber, forKey: "NSPersistentStoreRemoteChangeNotificationOptionKey")
            }
        }
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores(completionHandler: {
            completionHandler?($0, $1)
        })
        backgroundContext = container.newBackgroundContext()
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    /// Tracks and merges remote store changes
    ///
    /// For details see the following documentation:
    /// - [Consuming Relevant Store Changes](https://developer.apple.com/documentation/coredata/consuming_relevant_store_changes)
    /// - [Persistent History Tracking in Core Data](https://www.avanderlee.com/swift/persistent-history-tracking-core-data/)
    ///
    /// - Parameters:
    ///     - bundle: Tracker will ignore transactions from the `bundle`.
    @available(iOS 11.0, *)
    public func enablePersistentHistoryTracking(in bundle: Bundle) {
        let tracker = PersistentHistoryTracker(container: container)
        // only look for transactions created by other targets
        if let bundleIdentifier = bundle.bundleIdentifier {
            tracker.predicate = NSPredicate(format: "%K != %@", #keyPath(NSPersistentHistoryTransaction.bundleID), bundleIdentifier)
        }
        tracker.setObservationEnabled(true)
        self.tracker = tracker
    }
    
    /// Inserts a new entity to the store.
    ///
    /// - Parameters:
    ///     - completion: A block that is executed by the persistent container against a background context's queue.
    public func append(label: String, level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt, date: Date = Date(), completion: ((Error?) -> Void)? = nil) {
        backgroundContext.perform { [backgroundContext] in
            do {
                let entity = Entity(context: backgroundContext)
                entity.label = label
                entity.level = level.rawValue
                entity.message = "\(message)"
                if let metadata = metadata, !metadata.isEmpty {
                    entity.metadata = try JSONEncoder().encode(metadata)
                    entity.metadataNormalized = metadata.values.normalized()
                }
                entity.source = source
                entity.file = file
                entity.function = function
                entity.line = line as NSNumber
                entity.date = date
                
                try backgroundContext.save()
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    /// Returns an array of objects that meet the criteria specified by a given `searchTerm` and `levels` parameters.
    public func fetch(searchTerm: String? = nil, levels: Set<Logger.Level>? = nil) throws -> [Message] {
        let fetchRequest = createFetchRequest(searchTerm: searchTerm, levels: levels)
        return try container.viewContext.fetch(fetchRequest).map { Message(entity: $0) }
    }
    
    /// Notifies the receiver that the messages storage has completed processing of one or more changes due to an add, remove, move, or update.
    public func observe(searchTerm: String? = nil, levels: Set<Logger.Level>? = nil, sectionNameKeyPath: String? = nil, cacheName: String? = nil, didChangeContent: @escaping ([Message]) -> Void) throws -> FetchedResultsObservation {
        let fetchRequest = createFetchRequest(searchTerm: searchTerm, levels: levels)
        return try container.viewContext.observe(fetchRequest: fetchRequest, sectionNameKeyPath: sectionNameKeyPath, cacheName: cacheName, didChangeContent: { fetchedObjects in
            didChangeContent(fetchedObjects.map { Message(entity: $0) })
        })
    }
    
    /// Performs batch delete of all data in store
    public func delete(before date: Date = Date(), completion: ((Error?) -> Void)? = nil) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Entity.entity().name ?? "")
        fetchRequest.predicate = NSPredicate(format: "%K <= %@", #keyPath(Entity.date), date as NSDate)
        let viewContext = container.viewContext
        backgroundContext.perform { [backgroundContext] in
            do {
                try backgroundContext.executeBatchDeleteRequest(fetchRequest: fetchRequest,
                                                                mergeChangesInto: [viewContext, backgroundContext])
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    private func createFetchRequest(searchTerm: String? = nil, levels: Set<Logger.Level>? = nil) -> NSFetchRequest<Entity> {
        var searchTermPredicate: NSPredicate?
        if let searchTerm = searchTerm?.trimmingCharacters(in: .whitespaces), !searchTerm.isEmpty {
            searchTermPredicate = NSPredicate(format: "%K contains[cd] %@ or %K contains[cd] %@ or %K contains[cd] %@", #keyPath(Entity.label), searchTerm, #keyPath(Entity.message), searchTerm, #keyPath(Entity.metadataNormalized), searchTerm)
        }
        
        var levelsPredicate: NSPredicate?
        if let levels = Set(Logger.Level.allCases) == levels ? nil : levels {
            levelsPredicate = NSPredicate(format: "%K in %@", #keyPath(Entity.level), levels.map { $0.rawValue })
        }
        
        let subpredicates = [searchTermPredicate, levelsPredicate].compactMap { $0 }
        var predicate: NSCompoundPredicate?
        if !subpredicates.isEmpty {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        }
        
        let fetchRequest = NSFetchRequest<Entity>(entityName: Entity.entity().name ?? "")
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Entity.date, ascending: false)]
        
        return fetchRequest
    }
}

private extension Collection where Element == Logger.MetadataValue {
    func normalized() -> String {
        return map { $0.normalized() }.joined(separator: ", ")
    }
}

private extension Dictionary where Key == String, Value == Logger.MetadataValue {
    func normalized() -> String {
        return values.normalized()
    }
}

extension Logger.MetadataValue: Hashable, Codable {
    fileprivate func normalized() -> String {
        switch self {
        case .string(let string):
            return string
        case .stringConvertible(let stringConvertible):
            return "\(stringConvertible)"
        case .dictionary(let metadata):
            return metadata.normalized()
        case .array(let values):
            return values.normalized()
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let string):
            hasher.combine(string)
        case .stringConvertible(let stringConvertible):
            hasher.combine("\(stringConvertible)")
        case .dictionary(let metadata):
            hasher.combine(metadata)
        case .array(let values):
            hasher.combine(values)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([Logger.Metadata.Value].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode(Logger.Metadata.self) {
            self = .dictionary(dictionary)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Logger.MetadataValue cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let string):
            try container.encode(string)
        case .stringConvertible(let stringConvertible):
            try container.encode("\(stringConvertible)")
        case .dictionary(let metadata):
            try container.encode(metadata)
        case .array(let values):
            try container.encode(values)
        }
    }
}
