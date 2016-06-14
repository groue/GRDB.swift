import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabasePoolReadOnlyTests: GRDBTestCase {
    
    func testConcurrentRead() {
        assertNoError {
            let databaseFileName = "db.sqlite"
            
            // Create a non-WAL database:
            do {
                let dbQueue = try makeDatabaseQueue(filename: databaseFileName)
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for _ in 0..<3 {
                        try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    }
                }
            }
            
            // Open a read-only pool on that database:
            dbConfiguration.readonly = true
            let dbPool = try makeDatabasePool(filename: databaseFileName)
            
            // Make sure the database is not in WAL mode
            let mode = dbPool.read { db in
                String.fetchOne(db, "PRAGMA journal_mode")!
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
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    s1.signal()
                    _ = s2.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    let iterator = Row.fetch(db, "SELECT * FROM items").makeIterator()
                    XCTAssertTrue(iterator.next() != nil)
                    _ = s1.wait(timeout: .distantFuture)
                    XCTAssertTrue(iterator.next() != nil)
                    s2.signal()
                    XCTAssertTrue(iterator.next() != nil)
                    XCTAssertTrue(iterator.next() == nil)
                }
            }
            let blocks = [block1, block2]
            DispatchQueue.concurrentPerform(iterations: blocks.count) { index in
                blocks[index]()
            }
        }
    }
}
