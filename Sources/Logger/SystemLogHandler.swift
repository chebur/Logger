//
//  SystemLogHandler.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 20.08.2020.
//

import Foundation
import Logging

public struct SystemLogHandler: LogHandler {
    public let label: String
    
    public init(label: String) {
        self.label = label
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
        NSLog("\(message)")
    }
}
