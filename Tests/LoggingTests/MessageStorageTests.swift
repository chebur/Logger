//
//  MessageStorageTests.swift
//  UnitTests
//
//  Created by Dmitry Nesterenko on 21.08.2020.
//

import XCTest
@testable import Logger

final class MessageStorageTests: XCTestCase {
    
    static func createTempFile() -> URL {
        let temporaryDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryFilename = ProcessInfo().globallyUniqueString
        return temporaryDirectoryURL.appendingPathComponent(temporaryFilename)
    }
    
    func testAppendingMessages() throws {
        let storage = MessagesStorage(url: Self.createTempFile())

        let expectation = self.expectation(description: "")
        storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
    
    func testMessagesObservation() throws {
        try XCTContext.runActivity(named: "Given multiple messages appended") { _ in
            let storage = MessagesStorage(url: Self.createTempFile())
            
            // count number of changes
            let expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 2
            let observation = try storage.observe(didChangeContent: { objects in
                expectation.fulfill()
            })
            
            // append messages
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            
            // wait
            waitForExpectations(timeout: 1)
            observation.invalidate()
        }

        try XCTContext.runActivity(named: "Given observation was invalidated") { _ in
            let storage = MessagesStorage(url: Self.createTempFile())
            
            // count number of changes
            let expectation = self.expectation(description: "")
            expectation.isInverted = true
            let observation = try storage.observe(didChangeContent: { objects in
                expectation.fulfill()
            })
            
            // any changes after invalidation should not be counted
            observation.invalidate()
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            
            // wait
            waitForExpectations(timeout: 0.5)
        }
    }
    
    func testSearchingBySearchText() throws {
        let storage = MessagesStorage(url: Self.createTempFile())
        
        // append rows to storage
        let expectation = self.expectation(description: "")
        expectation.expectedFulfillmentCount = 2
        let observation = try storage.observe(didChangeContent: { objects in
            expectation.fulfill()
        })
        storage.append(label: "label1", level: .info, message: "message1", metadata: nil, source: "", file: "", function: "", line: 0)
        storage.append(label: "label2", level: .info, message: "message2", metadata: ["key": "metadata"], source: "", file: "", function: "", line: 0)
        
        // wait
        waitForExpectations(timeout: 1)
        observation.invalidate()
        
        // search by label
        XCTAssertEqual(try storage.fetch(searchTerm: "label").count, 2)
        
        // search by message
        XCTAssertEqual(try storage.fetch(searchTerm: "message").count, 2)
        
        // search by both label and message
        XCTAssertEqual(try storage.fetch(searchTerm: "1").count, 1)
        
        // search by metadata
        XCTAssertEqual(try storage.fetch(searchTerm: "metadata").count, 1)
    }
    
    func testRemovingAllRecordsFromStorage() throws {
        try XCTContext.runActivity(named: "Deleting all rows in storage") { _ in
            let storage = MessagesStorage(url: Self.createTempFile())

            // append few rows to storage
            var expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 3
            let observation = try storage.observe(didChangeContent: { objects in
                expectation.fulfill()
            })
            
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            
            // wait
            waitForExpectations(timeout: 1)
            observation.invalidate()
            
            // perform batch delete
            expectation = self.expectation(description: "")
            storage.delete { _ in
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1)

            // assert all rows are deleted
            let objects = try storage.fetch()
            XCTAssertEqual(objects.count, 0)
        }
        
        try XCTContext.runActivity(named: "Deleting all rows in storage") { _ in
            let storage = MessagesStorage(url: Self.createTempFile())
            
            // append rows to storage
            var expectation = self.expectation(description: "")
            expectation.expectedFulfillmentCount = 3
            let observation = try storage.observe(didChangeContent: { objects in
                expectation.fulfill()
            })
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0)
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0, date: Date().addingTimeInterval(-3600))
            storage.append(label: "", level: .info, message: "test", metadata: nil, source: "", file: "", function: "", line: 0, date: Date().addingTimeInterval(-3600))
            waitForExpectations(timeout: 1)
            observation.invalidate()
            
            // delete rows by date
            expectation = self.expectation(description: "")
            storage.delete(before: Date().addingTimeInterval(-2000)) { _ in
                expectation.fulfill()
            }
            waitForExpectations(timeout: 1)

            // assert all rows but latest one are deleted
            let objects = try storage.fetch()
            XCTAssertEqual(objects.count, 1)
        }
    }
}
