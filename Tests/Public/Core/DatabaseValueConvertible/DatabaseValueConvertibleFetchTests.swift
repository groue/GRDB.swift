import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A type that adopts DatabaseValueConvertible but does not adopt StatementColumnConvertible
private struct Fetched: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> Fetched? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return Fetched(int: int)
    }
}

class DatabaseValueConvertibleFetchTests: GRDBTestCase {
    
    // MARK: - DatabaseValueConvertible.fetch
    
    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched>) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchCursor(db, sql))
                    try test(Fetched.fetchCursor(statement))
                    try test(Fetched.fetchCursor(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchCursor(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchCursor(db, sql, adapter: adapter))
                    try test(Fetched.fetchCursor(statement, adapter: adapter))
                    try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchCursor(db))
                }
            }
        }
    }
    
    func testFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(Fetched.self)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(Fetched.self)")
                    }
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchCursor(db, sql), sql: sql)
                    try test(Fetched.fetchCursor(statement), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 21 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT throw() UNION ALL SELECT 2"
                    try test(Fetched.fetchCursor(db, sql), sql: sql)
                    try test(Fetched.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<Fetched>, sql: String) throws {
                    do {
                        _ = try cursor()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Fetched.fetchCursor(db, sql), sql: sql)
                    try test(Fetched.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [Fetched]) {
                    XCTAssertEqual(array.map { $0.int }, [1,2])
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchAll(db, sql))
                    try test(Fetched.fetchAll(statement))
                    try test(Fetched.fetchAll(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchAll(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchAll(db, sql, adapter: adapter))
                    try test(Fetched.fetchAll(statement, adapter: adapter))
                    try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchAll(db))
                }
            }
        }
    }
    
    func testFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(Fetched.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchAll(db, sql), sql: sql)
                    try test(Fetched.fetchAll(statement), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(Fetched.fetchAll(db, sql), sql: sql)
                    try test(Fetched.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Fetched.fetchAll(db, sql), sql: sql)
                    try test(Fetched.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: Fetched?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(Fetched.fetchOne(db, sql))
                        try test(Fetched.fetchOne(statement))
                        try test(Fetched.fetchOne(db, SQLRequest(sql)))
                        try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(Fetched.fetchOne(db, sql, adapter: adapter))
                        try test(Fetched.fetchOne(statement, adapter: adapter))
                        try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)))
                        try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db))
                    }
                }
                do {
                    func test(_ nilBecauseNull: Fetched?) {
                        XCTAssertTrue(nilBecauseNull == nil)
                    }
                    do {
                        let sql = "SELECT NULL"
                        let statement = try db.makeSelectStatement(sql)
                        try test(Fetched.fetchOne(db, sql))
                        try test(Fetched.fetchOne(statement))
                        try test(Fetched.fetchOne(db, SQLRequest(sql)))
                        try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, NULL"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(Fetched.fetchOne(db, sql, adapter: adapter))
                        try test(Fetched.fetchOne(statement, adapter: adapter))
                        try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)))
                        try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db))
                    }
                }
                do {
                    func test(_ value: Fetched?) {
                        XCTAssertEqual(value!.int, 1)
                    }
                    do {
                        let sql = "SELECT 1"
                        let statement = try db.makeSelectStatement(sql)
                        try test(Fetched.fetchOne(db, sql))
                        try test(Fetched.fetchOne(statement))
                        try test(Fetched.fetchOne(db, SQLRequest(sql)))
                        try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, 1"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(Fetched.fetchOne(db, sql, adapter: adapter))
                        try test(Fetched.fetchOne(statement, adapter: adapter))
                        try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)))
                        try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db))
                    }
                }
            }
        }
    }
    
    func testFetchOneConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> Fetched?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(Fetched.self)")
                    }
                }
                do {
                    let sql = "SELECT 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchOne(db, sql), sql: sql)
                    try test(Fetched.fetchOne(statement), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(statement, adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> Fetched?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(Fetched.fetchOne(db, sql), sql: sql)
                    try test(Fetched.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> Fetched?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Fetched.fetchOne(db, sql), sql: sql)
                    try test(Fetched.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Fetched.self).fetchOne(db), sql: sql)
                }
            }
        }
    }
    
    // MARK: - Optional<DatabaseValueConvertible>.fetch
    
    func testOptionalFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched?>) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<Fetched>.fetchCursor(db, sql))
                    try test(Optional<Fetched>.fetchCursor(statement))
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchCursor(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchCursor(db, sql, adapter: adapter))
                    try test(Optional<Fetched>.fetchCursor(statement, adapter: adapter))
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchCursor(db))
                }
            }
        }
    }
    
    func testOptionalFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched?>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(Fetched.self)")
                    }
                    XCTAssertEqual(try cursor.next()!!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<Fetched>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(statement), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchCursorStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Fetched?>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 21 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT throw() UNION ALL SELECT 2"
                    try test(Optional<Fetched>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<Fetched?>, sql: String) throws {
                    do {
                        _ = try cursor()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Optional<Fetched>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [Fetched?]) {
                    XCTAssertEqual(array.count, 2)
                    XCTAssertEqual(array[0]!.int, 1)
                    XCTAssertTrue(array[1] == nil)
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<Fetched>.fetchAll(db, sql))
                    try test(Optional<Fetched>.fetchAll(statement))
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchAll(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchAll(db, sql, adapter: adapter))
                    try test(Optional<Fetched>.fetchAll(statement, adapter: adapter))
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchAll(db))
                }
            }
        }
    }
    
    func testOptionalFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(Fetched.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(Fetched.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<Fetched>.fetchAll(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchAll(statement), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAllStepFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(Optional<Fetched>.fetchAll(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Fetched?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Optional<Fetched>.fetchAll(db, sql), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql)), sql: sql)
                    try test(SQLRequest(sql).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<Fetched>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<Fetched>.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                    try test(SQLRequest(sql, adapter: adapter).bound(to: Optional<Fetched>.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
}
