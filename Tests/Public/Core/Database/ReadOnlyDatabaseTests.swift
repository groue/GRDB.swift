import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class ReadOnlyDatabaseTests : GRDBTestCase {
    
    func testReadOnlyDatabaseCanNotBeModified() {
        assertNoError {
            // Create database
            do {
                try makeDatabaseQueue()
            }
            
            // Open it again, readonly
            dbConfiguration.readonly = true
            let dbQueue = try makeDatabaseQueue()
            let statement = try dbQueue.inDatabase { db in
                try db.makeUpdateStatement("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            }
            do {
                try dbQueue.inDatabase { db in
                    try statement.execute()
                }
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 8)   // SQLITE_READONLY
                XCTAssertEqual(error.message!, "attempt to write a readonly database")
                XCTAssertEqual(error.sql!, "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                XCTAssertEqual(error.description, "SQLite error 8 with statement `CREATE TABLE items (id INTEGER PRIMARY KEY)`: attempt to write a readonly database")
            }
        }
    }
}
