// Import C SQLite functions
#if GRDBCIPHER
import SQLCipher
#elseif SWIFT_PACKAGE
import GRDBSQLite
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import XCTest
@testable import GRDB

class DataMemoryTests: GRDBTestCase {
    
    func testMemoryBehavior() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Make sure Data is on the heap (15 bytes is enough)
            // For more context, see:
            // https://forums.swift.org/t/swift-5-how-to-test-data-bytesnocopydeallocator/20299/2?u=gwendal.roue
            let data = Data(repeating: 0xaa, count: 15)
            
            do {
                let rows = try Row.fetchCursor(db, sql: "SELECT ?", arguments: [data])
                while let row = try rows.next() {
                    let blobPointer = sqlite3_column_blob(row.sqliteStatement, 0)
                    
                    do {
                        // This data should be copied:
                        let copiedData: Data = row[0]
                        XCTAssertEqual(copiedData, data)
                        copiedData.withUnsafeBytes {
                            XCTAssertNotEqual($0.baseAddress, blobPointer)
                        }
                    }
                    
                    do {
                        // This data should not be copied
                        try row.withUnsafeData(atIndex: 0) { nonCopiedData in
                            XCTAssertEqual(nonCopiedData, data)
                            nonCopiedData!.withUnsafeBytes {
                                XCTAssertEqual($0.baseAddress, blobPointer)
                            }
                        }
                    }
                }
            }
            
            do {
                let adapter = ScopeAdapter(["nested": SuffixRowAdapter(fromIndex: 0)])
                let rows = try Row.fetchCursor(db, sql: "SELECT ?", arguments: [data], adapter: adapter)
                while let row = try rows.next() {
                    let blobPointer = sqlite3_column_blob(row.unadapted.sqliteStatement, 0)
                    let nestedRow = row.scopes["nested"]!
                    
                    do {
                        // This data should be copied:
                        let copiedData: Data = nestedRow[0]
                        XCTAssertEqual(copiedData, data)
                        copiedData.withUnsafeBytes {
                            XCTAssertNotEqual($0.baseAddress, blobPointer)
                        }
                    }
                    
                    do {
                        // This data should not be copied
                        try nestedRow.withUnsafeData(atIndex: 0) { nonCopiedData in
                            XCTAssertEqual(nonCopiedData, data)
                            nonCopiedData!.withUnsafeBytes {
                                XCTAssertEqual($0.baseAddress, blobPointer)
                            }
                        }
                    }
                }
            }
            
            do {
                let row = try Row.fetchOne(db, sql: "SELECT ?", arguments: [data])!
                let dbValue = row.first!.1 // TODO: think about exposing a (column:,databaseValue:) tuple
                switch dbValue.storage {
                case .blob(let data):
                    try data.withUnsafeBytes { buffer in
                        do {
                            // This data should not be copied:
                            let nonCopiedData: Data = row[0]
                            XCTAssertEqual(nonCopiedData, data)
                            nonCopiedData.withUnsafeBytes { nonCopiedBuffer in
                                XCTAssertEqual(nonCopiedBuffer.baseAddress, buffer.baseAddress)
                            }
                        }
                        
                        do {
                            // This data should not be copied:
                            try row.withUnsafeData(atIndex: 0) { nonCopiedData in
                                XCTAssertEqual(nonCopiedData, data)
                                nonCopiedData!.withUnsafeBytes { nonCopiedBuffer in
                                    XCTAssertEqual(nonCopiedBuffer.baseAddress, buffer.baseAddress)
                                }
                            }
                        }
                    }
                default:
                    XCTFail("Not a blob")
                }
            }
        }
    }
    
    @available(*, deprecated)
    func testDeprecatedMemoryBehavior() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Make sure Data is on the heap (15 bytes is enough)
            // For more context, see:
            // https://forums.swift.org/t/swift-5-how-to-test-data-bytesnocopydeallocator/20299/2?u=gwendal.roue
            let data = Data(repeating: 0xaa, count: 15)
            
            do {
                let rows = try Row.fetchCursor(db, sql: "SELECT ?", arguments: [data])
                while let row = try rows.next() {
                    let blobPointer = sqlite3_column_blob(row.sqliteStatement, 0)
                    // This data should not be copied
                    let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                    XCTAssertEqual(nonCopiedData, data)
                    nonCopiedData.withUnsafeBytes {
                        XCTAssertEqual($0.baseAddress, blobPointer)
                    }
                }
            }
            
            do {
                let adapter = ScopeAdapter(["nested": SuffixRowAdapter(fromIndex: 0)])
                let rows = try Row.fetchCursor(db, sql: "SELECT ?", arguments: [data], adapter: adapter)
                while let row = try rows.next() {
                    let blobPointer = sqlite3_column_blob(row.unadapted.sqliteStatement, 0)
                    let nestedRow = row.scopes["nested"]!
                    // This data should not be copied
                    let nonCopiedData = nestedRow.dataNoCopy(atIndex: 0)!
                    XCTAssertEqual(nonCopiedData, data)
                    nonCopiedData.withUnsafeBytes {
                        XCTAssertEqual($0.baseAddress, blobPointer)
                    }
                }
            }
            
            do {
                let row = try Row.fetchOne(db, sql: "SELECT ?", arguments: [data])!
                let dbValue = row.first!.1 // TODO: think about exposing a (column:,databaseValue:) tuple
                switch dbValue.storage {
                case .blob(let data):
                    data.withUnsafeBytes { buffer in
                        // This data should not be copied:
                        let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                        XCTAssertEqual(nonCopiedData, data)
                        nonCopiedData.withUnsafeBytes { nonCopiedBuffer in
                            XCTAssertEqual(nonCopiedBuffer.baseAddress, buffer.baseAddress)
                        }
                    }
                default:
                    XCTFail("Not a blob")
                }
            }
        }
    }
}
