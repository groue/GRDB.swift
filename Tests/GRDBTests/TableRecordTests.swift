import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class TableRecordTests: GRDBTestCase {
    
    func testDefaultDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"t1\"")
        }
    }
    
    func testExtendedDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
            static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"t1\"")
        }
    }
    
    func testRestrictedDatabaseSelection() throws {
        struct Record: TableRecord {
            static let databaseTableName = "t1"
            static let databaseSelection: [SQLSelectable] = [Column("a"), Column("b")]
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE t1(a,b,c)")
            _ = try Row.fetchAll(db, Record.all())
            XCTAssertEqual(lastSQLQuery, "SELECT \"a\", \"b\" FROM \"t1\"")
        }
    }
}
