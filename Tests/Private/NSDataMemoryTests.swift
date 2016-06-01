import XCTest

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class NSDataMemoryTests: GRDBTestCase {
    
    func testMemoryBehavior() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE datas (data BLOB)")
                
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                try db.execute("INSERT INTO datas (data) VALUES (?)", arguments: [data])
                
                for row in Row.fetch(db, "SELECT * FROM datas") {
                    let sqliteStatement = row.sqliteStatement
                    let sqliteBytes = sqlite3_column_blob(sqliteStatement, 0)
                    
                    do {
                        // This data should be copied:
                        let copiedData: NSData = row.value(atIndex: 0)
                        XCTAssertNotEqual(copiedData.bytes, sqliteBytes)
                        XCTAssertEqual(copiedData, data)
                    }
                    
                    do {
                        // This data should not be copied
                        let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                        XCTAssertEqual(nonCopiedData.bytes, sqliteBytes)
                        XCTAssertEqual(nonCopiedData, data)
                    }
                }
                
                let row = Row.fetchOne(db, "SELECT * FROM datas")!
                let databaseValue = row.first!.1
                switch databaseValue.storage {
                case .Blob(let data):
                    do {
                        // This data should not be copied:
                        let nonCopiedData: NSData = row.value(atIndex: 0)
                        XCTAssertEqual(nonCopiedData.bytes, data.bytes)
                        XCTAssertEqual(nonCopiedData, data)
                    }
                    
                    do {
                        // This data should not be copied:
                        let nonCopiedData = row.dataNoCopy(atIndex: 0)!
                        XCTAssertEqual(nonCopiedData.bytes, data.bytes)
                        XCTAssertEqual(nonCopiedData, data)
                    }
                default:
                    XCTFail("Not a blob")
                }
            }
        }
    }
}
