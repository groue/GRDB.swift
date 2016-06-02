import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolFunctionTests: GRDBTestCase {
    
    func testFunctionIsSharedBetweenWriterAndReaders() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            let function1 = DatabaseFunction("function1", argumentCount: 1, pure: true) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0]
            }
            
            dbPool.add(function: function1)
            
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (text TEXT)")
                try db.execute("INSERT INTO items (text) VALUES (function1('a'))")
            }
            dbPool.read { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT function1(text) FROM items")!, "a")
            }
            
            let function2 = DatabaseFunction("function2", argumentCount: 1, pure: true) { (databaseValues: [DatabaseValue]) in
                return "foo"
            }
            dbPool.add(function: function2)
            
            dbPool.read { db in
                XCTAssertTrue(String.fetchOne(db, "SELECT function2(text) FROM items") == "foo")
            }
        }
    }
}
