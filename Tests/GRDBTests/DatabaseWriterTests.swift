import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseWriterTests : GRDBTestCase {
    
    func testDatabaseQueueUnsafeReentrantWrite() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.unsafeReentrantWrite { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try dbQueue.unsafeReentrantWrite { db in
                try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
                try dbQueue.unsafeReentrantWrite { db in
                    try XCTAssertEqual(Int.fetchOne(db, "SELECT * FROM table1"), 1)
                }
            }
        }
    }
    
    func testDatabasePoolUnsafeReentrantWrite() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.unsafeReentrantWrite { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
            try dbPool.unsafeReentrantWrite { db in
                try db.execute("INSERT INTO table1 (id) VALUES (NULL)")
                try dbPool.unsafeReentrantWrite { db in
                    try XCTAssertEqual(Int.fetchOne(db, "SELECT * FROM table1"), 1)
                }
            }
        }
    }
}
