import XCTest
#if SWIFT_PACKAGE
    import CSQLite
#endif
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DataMemoryTests: GRDBTestCase {
    
    func testMemoryBehavior() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE datas (data BLOB)")
            
            let data = "foo".data(using: .utf8)
            try db.execute("INSERT INTO datas (data) VALUES (?)", arguments: [data])
            
            let rows = try Row.fetchCursor(db, "SELECT * FROM datas")
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM datas")!
            let dbValue = row.first!.1
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
