import XCTest
#if SQLITE_HAS_CODEC
    @testable import GRDBCipher
#else
    @testable import GRDB
#endif

class DatabasePoolBackupTests: GRDBTestCase {

    func testBackup() {
        assertNoError {
            let source = try makeDatabasePool(filename: "source.sqlite")
            let destination = try makeDatabasePool(filename: "destination.sqlite")
            
            try source.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
            }
            
            try source.backup(to: destination)
            
            destination.read { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
            }
            
            try source.write { db in
                try db.execute("DROP TABLE items")
            }
            
            try source.backup(to: destination)
            
            destination.read { db in
                XCTAssertFalse(db.tableExists("items"))
            }
        }
    }
    
    func testConcurrentWriteDuringBackup() {
        assertNoError {
            let source = try makeDatabasePool(filename: "source.sqlite")
            let destination = try makeDatabasePool(filename: "destination.sqlite")
            
            try source.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
            }
            
            let s1 = dispatch_semaphore_create(0)!
            let s2 = dispatch_semaphore_create(0)!
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                try! source.writeInTransaction(.immediate) { db in
                    try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    dispatch_semaphore_signal(s2)
                    return .commit
                }
            }
            
            try source.backup(
                to: destination,
                afterBackupInit: {
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                },
                afterBackupStep: {
                    try! source.write { db in
                        try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    }
                })
            
            source.read { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 3)
            }
            destination.read { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 2)
            }
        }
    }
}
