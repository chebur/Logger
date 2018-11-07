//
//  Writer.swift
//  Logger
//
//  Created by Dmitry Nesterenko on 26/09/2017.
//  Copyright © 2017 chebur. All rights reserved.
//

import Foundation
import os.log
import os.activity

public protocol Writer {
    
    func log(_ message: StaticString, level: Logger.Level, _ args: CVarArg...)
    
    func logv(_ message: StaticString, level: Logger.Level, _ args: [CVarArg])
    
}

extension Writer {
    
    public func log(_ message: StaticString, level: Logger.Level, _ args: CVarArg...) {
        logv(message, level: level, args)
    }
    
}

@available(iOS 10, *)
public final class UnifiedLogWriter: Writer {
    
    let log: OSLog
    
    public required init(subsystem: String, category: String) {
        self.log = OSLog(subsystem: subsystem, category: category)
    }

    private func log(_ message: StaticString, type: OSLogType) {
        os_log(message, log: log, type: type)
    }
    
    private func log(_ message: StaticString, type: OSLogType, _ arg0: CVarArg) {
        os_log(message, log: log, type: type, arg0)
    }
    
    private func log(_ message: StaticString, type: OSLogType, _ arg0: CVarArg, _ arg1: CVarArg) {
        os_log(message, log: log, type: type, arg0, arg1)
    }
    
    private func log(_ message: StaticString, type: OSLogType, _ arg0: CVarArg, _ arg1: CVarArg, _ arg2: CVarArg) {
        os_log(message, log: log, type: type, arg0, arg1, arg2)
    }
    
    private func log(_ message: StaticString, type: OSLogType, _ arg0: CVarArg, _ arg1: CVarArg, _ arg2: CVarArg, _ arg3: CVarArg) {
        os_log(message, log: log, type: type, arg0, arg1, arg2, arg3)
    }
    
    private func log(_ message: StaticString, type: OSLogType, _ arg0: CVarArg, _ arg1: CVarArg, _ arg2: CVarArg, _ arg3: CVarArg, _ arg4: CVarArg) {
        os_log(message, log: log, type: type, arg0, arg1, arg2, arg3, arg4)
    }
    
    public func logv(_ message: StaticString, level: Logger.Level, _ args: [CVarArg]) {
        let type = UnifiedLogWriter.logType(fromLogLevel: level)

        switch args.count {
        case 0:
            log(message, type: type)
        case 1:
            log(message, type: type, args[0])
        case 2:
            log(message, type: type, args[0], args[1])
        case 3:
            log(message, type: type, args[0], args[1], args[2])
        case 4:
            log(message, type: type, args[0], args[1], args[2], args[3])
        case 5:
            log(message, type: type, args[0], args[1], args[2], args[3], args[4])
        default:
            assertionFailure("Not implemented")
        }
    }
    
    private static func logType(fromLogLevel level: Logger.Level) -> OSLogType {
        switch level {
        case .default:
            return .default
        case .info:
            return .info
        case .debug:
            return .debug
        case .error:
            return .error
        case .fault:
            return .fault
        }
    }
    
}

public final class NSLogWriter: Writer {
    
    public func logv(_ message: StaticString, level: Logger.Level, _ args: [CVarArg]) {
        withVaList(args) { pointer in
            NSLogv("\(message)", pointer)
        }
    }
    
}

public final class CompositeLogWriter : Writer, RangeReplaceableCollection {
    private var writers: [Writer]

    public init() {
        self.writers = []
    }

    public func logv(_ message: StaticString, level: Logger.Level, _ args: [CVarArg]) {
        forEach { $0.logv(message, level: level, args) }
    }

    // MARK: Collection

    public var startIndex: Int {
        return writers.startIndex
    }

    public var endIndex: Int {
        return writers.endIndex
    }

    public subscript (position: Int) -> Writer {
        get {
            return writers[position]
        }
    }

    public func index(after i: Int) -> Int {
        return writers.index(after: i)
    }

    // MARK: Range Replaceable Collection

    public func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, C.Iterator.Element == Writer {
        writers.replaceSubrange(subrange, with: newElements)
    }

}
