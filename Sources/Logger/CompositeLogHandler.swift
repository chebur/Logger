//
//  CompositeLogHandler.swift
//  Logging
//
//  Created by Dmitry Nesterenko on 20.08.2020.
//

import Foundation
import Logging

public struct CompositeLogHandler: LogHandler, RangeReplaceableCollection {
    private var logHandlers = [LogHandler]()

    public init() {}

    // MARK: - Collection

    public var startIndex: Int {
        return logHandlers.startIndex
    }

    public var endIndex: Int {
        return logHandlers.endIndex
    }

    public subscript (position: Int) -> LogHandler {
        return logHandlers[position]
    }

    public func index(after i: Int) -> Int {
        return logHandlers.index(after: i)
    }

    // MARK: - Range Replaceable Collection

    mutating public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Iterator.Element == LogHandler {
        logHandlers.replaceSubrange(subrange, with: newElements)
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
        forEach { $0.log(level: level, message: message, metadata: metadata, source: source, file: file, function: function, line: line) }
    }
}
