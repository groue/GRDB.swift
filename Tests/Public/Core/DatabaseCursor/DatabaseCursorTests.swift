import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCursorTests: GRDBTestCase {
    
    func testNextReturnsNilAfterExhaustion() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1 WHERE 0")
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1")
                    XCTAssertEqual(try cursor.next()!,  1)
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
                do {
                    let cursor = try Int.fetchCursor(db, "SELECT 1 UNION ALL SELECT 2")
                    XCTAssertEqual(try cursor.next()!, 1)
                    XCTAssertEqual(try cursor.next()!, 2)
                    XCTAssert(try cursor.next() == nil) // end
                    XCTAssert(try cursor.next() == nil) // past the end
                }
            }
        }
    }
    
    func testStepError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                let cursor = try Int.fetchCursor(db, "SELECT 1 UNION ALL SELECT throw()")
                XCTAssertEqual(try cursor.next()!, 1)
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, "SELECT 1 UNION ALL SELECT throw()")
                    XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT 1 UNION ALL SELECT throw()`: \(customError)")
                }
            }
        }
    }
}
