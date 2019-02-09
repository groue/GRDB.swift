import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

class DataMemoryTests: GRDBTestCase {
    
    func testMemoryBehavior() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            // Make sure Data is on the heap (15 bytes is enough)
            // For more context, see:
            // https://forums.swift.org/t/swift-5-how-to-test-data-bytesnocopydeallocator/20299/2?u=gwendal.roue
            let data = Data(repeating: 0xaa, count: 15)
            
            let rows = try Row.fetchCursor(db, "SELECT ?", arguments: [data])
            while let row = try rows.next() {
                let sqliteStatement = row.sqliteStatement
                let sqliteBytes = sqlite3_column_blob(sqliteStatement, 0)
                
                do {
                    // This data should be copied:
                    let copiedData: Data = row[0]
                    copiedData.withUnsafeBytes { copiedBytes in
                        XCTAssertNotEqual(copiedBytes, sqliteBytes)
                    }
                    XCTAssertEqual(copiedData, data)
                }
                
                do {
                    // This data should not be copied
                    let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                    nonCopiedData.withUnsafeBytes { nonCopiedBytes in
                        XCTAssertEqual(nonCopiedBytes, sqliteBytes)
                    }
                    XCTAssertEqual(nonCopiedData, data)
                }
            }
            
            let row = try Row.fetchOne(db, "SELECT ?", arguments: [data])!
            let dbValue = row.first!.1 // TODO: think about exposing a (column:,databaseValue:) tuple
            switch dbValue.storage {
            case .blob(let data):
                data.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) -> Void in
                    do {
                        // This data should not be copied:
                        let nonCopiedData: Data = row[0]
                        nonCopiedData.withUnsafeBytes { nonCopiedBytes in
                            XCTAssertEqual(nonCopiedBytes, dataBytes)
                        }
                        XCTAssertEqual(nonCopiedData, data)
                    }
                    
                    do {
                        // This data should not be copied:
                        let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                        nonCopiedData.withUnsafeBytes { nonCopiedBytes in
                            XCTAssertEqual(nonCopiedBytes, dataBytes)
                        }
                        XCTAssertEqual(nonCopiedData, data)
                    }
                }
            default:
                XCTFail("Not a blob")
            }
        }
    }
}
