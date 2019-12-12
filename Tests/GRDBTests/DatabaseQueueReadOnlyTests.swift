import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueReadOnlyTests : GRDBTestCase {
    
    func testOpenReadOnlyMissingDatabase() throws {
        dbConfiguration.readonly = true
        do {
            _ = try makeDatabaseQueue()
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CANTOPEN)
        }
    }
    
    func testReadOnlyDatabaseCanNotBeModified() throws {
        // Create database
        do {
            _ = try makeDatabaseQueue(filename: "test.sqlite")
        }
        
        // Open it again, readonly
        dbConfiguration.readonly = true
        let dbQueue = try makeDatabaseQueue(filename: "test.sqlite")
        let statement = try dbQueue.inDatabase { db in
            try db.makeUpdateStatement(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
        }
        do {
            try dbQueue.inDatabase { db in
                try statement.execute()
            }
            XCTFail()
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            XCTAssertEqual(error.message!, "attempt to write a readonly database")
            XCTAssertEqual(error.sql!, "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            XCTAssertEqual(error.description, "SQLite error 8 with statement `CREATE TABLE items (id INTEGER PRIMARY KEY)`: attempt to write a readonly database")
        }
    }
}
