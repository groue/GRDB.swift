import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class InMemoryDatabaseTests : GRDBTestCase
{
    func testInMemoryDatabase() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE foo (bar TEXT)")
                try db.execute("INSERT INTO foo (bar) VALUES ('baz')")
                let baz = String.fetchOne(db, "SELECT bar FROM foo")!
                XCTAssertEqual(baz, "baz")
                return .rollback
            }
        }
    }
}
