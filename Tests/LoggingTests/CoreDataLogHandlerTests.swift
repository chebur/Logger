//
//  CoreDataLogHandlerTests.swift
//  UnitTests
//
//  Created by Dmitry Nesterenko on 20.08.2020.
//

import XCTest
import Logging
@testable import Logger

final class CoreDataLogHandlerTests: XCTestCase {
    func testCoreDataLogHandlerIsAValueType() {
        var logger1 = Logger(label: "first logger")
        logger1.logLevel = .debug
        logger1[metadataKey: "only-on"] = "first"
        var logger2 = logger1
        logger2.logLevel = .error                  // this must not override `logger1`'s log level
        logger2[metadataKey: "only-on"] = "second" // this must not override `logger1`'s metadata
        
        XCTAssertEqual(.debug, logger1.logLevel)
        XCTAssertEqual(.error, logger2.logLevel)
        XCTAssertEqual("first", logger1[metadataKey: "only-on"])
        XCTAssertEqual("second", logger2[metadataKey: "only-on"])
    }
    
    func testMetadataCoding() throws {
        // setup
        let storage = MessagesStorage(url: MessageStorageTests.createTempFile())
        let logger = Logger(label: "") { CoreDataLogHandler(label: $0, storage: storage) }
        
        // log messages with metadata
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 3
        let observation = try storage.observe { _ in
            expectation.fulfill()
        }
        
        logger.info("user logged in", metadata: ["user-id": "1"])
        logger.info("user selected colors", metadata: ["colors": ["topColor", "secondColor"]])
        logger.info("nested info", metadata: ["nested": ["fave-numbers": ["1", "2", "3"], "foo": "bar"]])
        waitForExpectations(timeout: 1)
        observation.invalidate()
        
        let objects = try storage.fetch()
        XCTAssertEqual(objects.count, 3)
        XCTAssertTrue(objects.contains(where: { $0.metadata == ["user-id": "1"] }))
        XCTAssertTrue(objects.contains(where: { $0.metadata == ["colors": ["topColor", "secondColor"]] }))
        XCTAssertTrue(objects.contains(where: { $0.metadata == ["nested": ["fave-numbers": ["1", "2", "3"], "foo": "bar"]] }))
    }
    
    func testSimultaneousLoggingUsingSeveralLoggersAtSameTime() throws {
        // setup
        let storage = MessagesStorage(url: MessageStorageTests.createTempFile())
        let firebaseLogger = Logger(label: "firebase") { CoreDataLogHandler(label: $0, storage: storage) }
        let metrikaLogger = Logger(label: "metrika") { CoreDataLogHandler(label: $0, storage: storage) }
        
        // check total count of logged messages
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let observation = try storage.observe(didChangeContent: { objects in
            expectation.fulfill()
        })
        
        // write log messages simultaneously
        firebaseLogger.info("message to firebase")
        metrikaLogger.info("message to metrika")
        waitForExpectations(timeout: 1)
        observation.invalidate()
    }
}
