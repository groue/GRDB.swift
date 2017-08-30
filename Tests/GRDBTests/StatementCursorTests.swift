import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class StatementCursorTests: GRDBTestCase {

    func testStatementCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let statement = try db.makeSelectStatement("SELECT 1 UNION ALL SELECT 2")
            let cursor = statement.cursor()
            var i = 0
            while let _ = try cursor.next() {
                i = i + 1
            }
            XCTAssertEqual(i, 2)
        }
    }

}
