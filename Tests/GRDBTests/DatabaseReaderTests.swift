import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseReaderTests : GRDBTestCase {
    
    func testDatabaseQueueReadPreventsDatabaseModification() throws {
        // query_only pragma was added in SQLite 3.8.0 http://www.sqlite.org/changes.html#version_3_8_0
        // It is available from iOS 8.2 and OS X 10.10 https://github.com/yapstudios/YapDatabase/wiki/SQLite-version-(bundled-with-OS)
        #if !GRDBCUSTOMSQLITE && !GRDBCIPHER
            guard #available(iOS 8.2, OSX 10.10, *) else {
                return
            }
        #endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        do {
            try dbQueue.read { try $0.execute("INSERT INTO table1 DEFAULT VALUES") }
            XCTFail()
        } catch let error as DatabaseError where error.resultCode == .SQLITE_READONLY {
        }
    }
    
    func testDatabasePoolReadPreventsDatabaseModification() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.create(table: "table1") { t in
                t.column("id", .integer).primaryKey()
            }
        }
        do {
            try dbPool.read { try $0.execute("INSERT INTO table1 DEFAULT VALUES") }
            XCTFail()
        } catch let error as DatabaseError where error.resultCode == .SQLITE_READONLY {
        }
    }

    func testDatabaseQueueUnsafeReentrantRead() throws {
        let dbQueue = try makeDatabaseQueue()
        dbQueue.unsafeReentrantRead { db1 in
            dbQueue.unsafeReentrantRead { db2 in
                dbQueue.unsafeReentrantRead { db3 in
                    XCTAssertTrue(db1 === db2)
                    XCTAssertTrue(db2 === db3)
                }
            }
        }
    }
    
    func testDatabasePoolUnsafeReentrantRead() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.unsafeReentrantRead { db1 in
            try dbPool.unsafeReentrantRead { db2 in
                try dbPool.unsafeReentrantRead { db3 in
                    XCTAssertTrue(db1 === db2)
                    XCTAssertTrue(db2 === db3)
                }
            }
        }
    }
    
    func testAnyDatabaseReader() {
        // This test passes if this code compiles.
        let reader: DatabaseReader = DatabaseQueue()
        let _: DatabaseReader = AnyDatabaseReader(reader)
    }
}
