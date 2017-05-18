import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseCursorTests: GRDBTestCase {
    
    func testNextReturnsNilAfterExhaustion() throws {
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

    func testStepError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            let cursor = try Int.fetchCursor(db, "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.message, DatabaseError(error: customError).message)
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT throw()`: \(DatabaseError(error: customError).message!)")
            }
        }
    }

    func testStepDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = DatabaseError(resultCode: ResultCode(rawValue: 0xDEAD), message: "custom error")
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            let cursor = try Int.fetchCursor(db, "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.extendedResultCode.rawValue, 0xDEAD)
                XCTAssertEqual(error.message, "custom error")
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.description, "SQLite error 57005 with statement `SELECT throw()`: custom error")
            }
        }
    }
}
