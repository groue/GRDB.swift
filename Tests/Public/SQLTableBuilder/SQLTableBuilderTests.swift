import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLTableBuilderTests: GRDBTestCase {

    func testCreateTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Simple table creation
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY, " +
                        "\"name\" TEXT" +
                    ")")
            }
        }
    }
    
    func testTableCreationOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                    t.column("id", .Integer).primaryKey()
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY" +
                    ") WITHOUT ROWID")
            }
        }
    }
    
    func testColumnPrimaryKeyOptions() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey(ordering: .Desc, onConflict: .Fail)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY DESC ON CONFLICT FAIL" +
                    ")")
                return .Rollback
            }
            try dbQueue.inTransaction { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey(autoincrement: true)
                }
                XCTAssertEqual(self.lastSQLQuery,
                    "CREATE TABLE \"test\" (" +
                        "\"id\" INTEGER PRIMARY KEY AUTOINCREMENT" +
                    ")")
                return .Rollback
            }
        }
    }
    
    func testDropTable() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                }
                XCTAssertTrue(db.tableExists("test"))
                
                try db.drop(table: "test")
                XCTAssertEqual(self.lastSQLQuery, "DROP TABLE \"test\"")
                XCTAssertFalse(db.tableExists("test"))
            }
        }
    }
}
