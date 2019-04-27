import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueBackupTests: GRDBTestCase {

    func testBackup() throws {
        #if GRDBCIPHER
        // SQLCipher can't backup encrypted databases: skip this test
        if dbConfiguration.passphrase != nil {
            return
        }
        #endif
        
        let source = try makeDatabaseQueue(filename: "source.sqlite")
        let destination = try makeDatabaseQueue(filename: "destination.sqlite")
        
        try source.inDatabase { db in
            try db.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.backup(to: destination)
        
        try destination.inDatabase { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items")!, 1)
        }
        
        try source.inDatabase { db in
            try db.execute(sql: "DROP TABLE items")
        }
        
        try source.backup(to: destination)
        
        try destination.inDatabase { db in
            XCTAssertFalse(try db.tableExists("items"))
        }
    }
}
