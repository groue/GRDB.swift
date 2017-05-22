import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueBackupTests: GRDBTestCase {

    func testBackup() throws {
        let source = try makeDatabaseQueue(filename: "source.sqlite")
        let destination = try makeDatabaseQueue(filename: "destination.sqlite")
        
        try source.inDatabase { db in
            try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute("INSERT INTO items (id) VALUES (NULL)")
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.backup(to: destination)
        
        try destination.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.inDatabase { db in
            try db.execute("DROP TABLE items")
        }
        
        try source.backup(to: destination)
        
        try destination.inDatabase { db in
            XCTAssertFalse(try db.tableExists("items"))
        }
    }
}
