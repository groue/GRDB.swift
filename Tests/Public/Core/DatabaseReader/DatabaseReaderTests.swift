import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseReaderTests : GRDBTestCase {
    
    func testDatabaseQueueReadPreventsDatabaseModification() throws {
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
}
