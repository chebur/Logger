//
//  CoreDataLogHandler.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 20.08.2020.
//

import Foundation
import CoreData
import Logging

public struct CoreDataLogHandler: LogHandler {
    let label: String
    let storage: MessagesStorage
    
    public init(label: String, storage: MessagesStorage) {
        self.label = label
        self.storage = storage
    }
    
    // MARK: - Log Handler
    
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.info
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return metadata[metadataKey]
        }
        set(newValue) {
            metadata[metadataKey] = newValue
        }
    }
    
    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
        guard logLevel <= level else { return }
        storage.append(label: label, level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line)
    }
}
