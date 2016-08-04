import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class SQLTableBuilderTests: GRDBTestCase {

    func testSQLTableBuilder() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                // Simple table creation
                try db.create(table: "test") { t in
                    t.column("id", .Integer).primaryKey()
                    t.column("name", .Text)
                }
                XCTAssertEqual(self.lastSQLQuery, "CREATE TABLE \"test\" (\"id\" INTEGER PRIMARY KEY, \"name\" TEXT)")
                
                // Drop table
                try db.drop(table: "test")
                XCTAssertEqual(self.lastSQLQuery, "DROP TABLE \"test\"")
                
                // Table options and column primary key options
                try db.create(table: "test", temporary: true, ifNotExists: true, withoutRowID: true) { t in
                    t.column("id", .Integer).primaryKey(ordering: .Desc, onConflict: .Fail)
                }
                XCTAssertEqual(self.lastSQLQuery, "CREATE TEMPORARY TABLE IF NOT EXISTS \"test\" (\"id\" INTEGER PRIMARY KEY DESC ON CONFLICT FAIL) WITHOUT ROWID")
            }
        }
    }
}
