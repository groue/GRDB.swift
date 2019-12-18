import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolReadOnlyTests: GRDBTestCase {
    
    func testOpenReadOnlyMissingDatabase() throws {
        dbConfiguration.readonly = true
        do {
            _ = try makeDatabasePool()
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_CANTOPEN)
        }
    }
    
    func testConcurrentRead() throws {
        let databaseFileName = "db.sqlite"
        
        // Create a non-WAL database:
        do {
            let dbQueue = try makeDatabaseQueue(filename: databaseFileName)
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                for _ in 0..<3 {
                    try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
                }
            }
        }
        
        // Open a read-only pool on that database:
        dbConfiguration.readonly = true
        let dbPool = try makeDatabasePool(filename: databaseFileName)
        
        // Make sure the database is not in WAL mode
        let mode = try dbPool.read { db in
            try String.fetchOne(db, sql: "PRAGMA journal_mode")!
        }
        XCTAssertNotEqual(mode.lowercased(), "wal")
        
        // Block 1                  Block 2
        // SELECT * FROM items      SELECT * FROM items
        // step                     step
        // >
        let s1 = DispatchSemaphore(value: 0)
        //                          step
        //                          <
        let s2 = DispatchSemaphore(value: 0)
        // step                     step
        // step                     end
        // end
        
        let block1 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                s1.signal()
                _ = s2.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let block2 = { () in
            try! dbPool.read { db in
                let cursor = try Row.fetchCursor(db, sql: "SELECT * FROM items")
                XCTAssertTrue(try cursor.next() != nil)
                _ = s1.wait(timeout: .distantFuture)
                XCTAssertTrue(try cursor.next() != nil)
                s2.signal()
                XCTAssertTrue(try cursor.next() != nil)
                XCTAssertTrue(try cursor.next() == nil)
            }
        }
        let blocks = [block1, block2]
        DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
            blocks[index]()
        }
    }
}
