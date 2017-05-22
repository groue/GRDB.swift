import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseQueueInMemoryTests : GRDBTestCase
{
    func testInMemoryDatabase() throws {
        let dbQueue = DatabaseQueue()
        try dbQueue.inTransaction { db in
            try db.execute("CREATE TABLE foo (bar TEXT)")
            try db.execute("INSERT INTO foo (bar) VALUES ('baz')")
            let baz = try String.fetchOne(db, "SELECT bar FROM foo")!
            XCTAssertEqual(baz, "baz")
            return .rollback
        }
    }
}
