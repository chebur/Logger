//
//  Logger.swift
//  Logger
//
//  Created by Dmitry Nesterenko on 26/09/2017.
//  Copyright © 2017 chebur. All rights reserved.
//

import Foundation

public final class Logger {
    
    public enum Level {
        
        case `default`
        
        case info
        
        case debug
        
        case error
        
        case fault
        
    }
    
    public static let `default`: Logger = Logger(subsystem: "", category: "default")
    
    let writer: Writer
    
    var enabled: Bool = true
    
    init(writer: Writer) {
        self.writer = writer
    }
    
    public required init(subsystem: String, category: String) {
        let writer: Writer
        if #available(iOS 10, *) {
            writer = UnifiedLogWriter(subsystem: subsystem, category: category)
        } else {
            writer = NSLogWriter(subsystem: subsystem, category: category)
        }
        self.writer = writer
    }
    
    fileprivate func logv(_ message: StaticString, level: Logger.Level, _ args: [CVarArg]) {
        guard enabled else { return }
        writer.logv(message, level: level, args)
    }
    
}

extension Logger {
    
    public func log(_ message: StaticString, _ args: CVarArg...) {
        logv(message, level: .default, args)
    }
    
    public func info(_ message: StaticString, _ args: CVarArg...) {
        logv(message, level: .info, args)
    }
    
    public func debug(_ message: StaticString, _ args: CVarArg...) {
        logv(message, level: .debug, args)
    }
    
    public func error(_ message: StaticString, _ args: CVarArg...) {
        logv(message, level: .error, args)
    }
    
    public func fault(_ message: StaticString, _ args: CVarArg...) {
        logv(message, level: .fault, args)
    }
    
    public func log(_ message: StaticString, level: Logger.Level, _ args: CVarArg...) {
        logv(message, level: level, args)
    }
    
}
