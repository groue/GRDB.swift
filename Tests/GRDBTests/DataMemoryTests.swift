import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if GRDBCIPHER
        import SQLCipher
    #elseif SWIFT_PACKAGE
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
            
            let rows = try Row.fetchCursor(db, sql: "SELECT ?", arguments: [data])
            while let row = try rows.next() {
                let blobPointer = sqlite3_column_blob(row.sqliteStatement, 0)
                
                do {
                    // This data should be copied:
                    let copiedData: Data = row[0]
                    XCTAssertEqual(copiedData, data)
                    copiedData.withBaseAddress { dataPointer in
                        XCTAssertNotEqual(dataPointer, blobPointer)
                    }
                }
                
                do {
                    // This data should not be copied
                    let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                    XCTAssertEqual(nonCopiedData, data)
                    nonCopiedData.withBaseAddress { dataPointer in
                        XCTAssertEqual(dataPointer, blobPointer)
                    }
                }
            }
            
            let row = try Row.fetchOne(db, sql: "SELECT ?", arguments: [data])!
            let dbValue = row.first!.1 // TODO: think about exposing a (column:,databaseValue:) tuple
            switch dbValue.storage {
            case .blob(let data):
                data.withBaseAddress { dataPointer in
                    do {
                        // This data should not be copied:
                        let nonCopiedData: Data = row[0]
                        XCTAssertEqual(nonCopiedData, data)
                        nonCopiedData.withBaseAddress { nonCopiedBytes in
                            XCTAssertEqual(nonCopiedBytes, dataPointer)
                        }
                    }
                    
                    do {
                        // This data should not be copied:
                        let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                        XCTAssertEqual(nonCopiedData, data)
                        nonCopiedData.withBaseAddress { nonCopiedBytes in
                            XCTAssertEqual(nonCopiedBytes, dataPointer)
                        }
                    }
                }
            default:
                XCTFail("Not a blob")
            }
        }
    }
}

extension Data {
    // Helper for comparing data heap pointers, depending on the Swift version
    fileprivate func withBaseAddress(_ body: (UnsafeRawPointer?) -> Void) {
        #if swift(>=5.0)
        withUnsafeBytes {
            body($0.baseAddress)
        }
        #else
        withUnsafeBytes {
            body(UnsafeRawPointer($0))
        }
        #endif
    }
}
