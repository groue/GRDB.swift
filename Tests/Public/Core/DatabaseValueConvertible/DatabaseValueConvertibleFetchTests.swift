import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A type that adopts DatabaseValueConvertible but does not adopt StatementColumnConvertible
private struct FetchedType: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FetchedType? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return FetchedType(int: int)
    }
}

class DatabaseValueConvertibleFetchTests: GRDBTestCase {
    
    // MARK: - DatabaseValueConvertible.fetch
    
    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FetchedType>) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FetchedType.fetchCursor(db, sql))
                    try test(FetchedType.fetchCursor(statement))
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql)))
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchCursor(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchCursor(db, sql, adapter: adapter))
                    try test(FetchedType.fetchCursor(statement, adapter: adapter))
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchCursor(db))
                }
            }
        }
    }
    
    func testFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FetchedType>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(FetchedType.self)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FetchedType.self)")
                    }
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FetchedType.fetchCursor(db, sql), sql: sql)
                    try test(FetchedType.fetchCursor(statement), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
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
                func test(_ cursor: DatabaseCursor<FetchedType>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 21 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT throw() UNION ALL SELECT 2"
                    try test(FetchedType.fetchCursor(db, sql), sql: sql)
                    try test(FetchedType.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<FetchedType>, sql: String) throws {
                    do {
                        _ = try cursor()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(FetchedType.fetchCursor(db, sql), sql: sql)
                    try test(FetchedType.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [FetchedType]) {
                    XCTAssertEqual(array.map { $0.int }, [1,2])
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FetchedType.fetchAll(db, sql))
                    try test(FetchedType.fetchAll(statement))
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql)))
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchAll(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchAll(db, sql, adapter: adapter))
                    try test(FetchedType.fetchAll(statement, adapter: adapter))
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchAll(db))
                }
            }
        }
    }
    
    func testFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FetchedType], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(FetchedType.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FetchedType.fetchAll(db, sql), sql: sql)
                    try test(FetchedType.fetchAll(statement), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchAll(db), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [FetchedType], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(FetchedType.fetchAll(db, sql), sql: sql)
                    try test(FetchedType.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FetchedType], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(FetchedType.fetchAll(db, sql), sql: sql)
                    try test(FetchedType.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: FetchedType?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FetchedType.fetchOne(db, sql))
                        try test(FetchedType.fetchOne(statement))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)))
                        try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FetchedType.fetchOne(db, sql, adapter: adapter))
                        try test(FetchedType.fetchOne(statement, adapter: adapter))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                        try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db))
                    }
                }
                do {
                    func test(_ nilBecauseNull: FetchedType?) {
                        XCTAssertTrue(nilBecauseNull == nil)
                    }
                    do {
                        let sql = "SELECT NULL"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FetchedType.fetchOne(db, sql))
                        try test(FetchedType.fetchOne(statement))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)))
                        try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, NULL"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FetchedType.fetchOne(db, sql, adapter: adapter))
                        try test(FetchedType.fetchOne(statement, adapter: adapter))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                        try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db))
                    }
                }
                do {
                    func test(_ value: FetchedType?) {
                        XCTAssertEqual(value!.int, 1)
                    }
                    do {
                        let sql = "SELECT 1"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FetchedType.fetchOne(db, sql))
                        try test(FetchedType.fetchOne(statement))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)))
                        try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db))
                    }
                    do {
                        let sql = "SELECT 0, 1"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FetchedType.fetchOne(db, sql, adapter: adapter))
                        try test(FetchedType.fetchOne(statement, adapter: adapter))
                        try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                        try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db))
                    }
                }
            }
        }
    }
    
    func testFetchOneConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> FetchedType?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FetchedType.self)")
                    }
                }
                do {
                    let sql = "SELECT 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FetchedType.fetchOne(db, sql), sql: sql)
                    try test(FetchedType.fetchOne(statement), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(statement, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db), sql: sql)
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
                func test(_ value: @autoclosure () throws -> FetchedType?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(FetchedType.fetchOne(db, sql), sql: sql)
                    try test(FetchedType.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> FetchedType?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(FetchedType.fetchOne(db, sql), sql: sql)
                    try test(FetchedType.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: FetchedType.self).fetchOne(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FetchedType.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FetchedType.fetchOne(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: FetchedType.self).fetchOne(db), sql: sql)
                }
            }
        }
    }
    
    // MARK: - Optional<DatabaseValueConvertible>.fetch
    
    func testOptionalFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FetchedType?>) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FetchedType>.fetchCursor(db, sql))
                    try test(Optional<FetchedType>.fetchCursor(statement))
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql)))
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchCursor(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchCursor(db, sql, adapter: adapter))
                    try test(Optional<FetchedType>.fetchCursor(statement, adapter: adapter))
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchCursor(db))
                }
            }
        }
    }
    
    func testOptionalFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FetchedType?>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FetchedType.self)")
                    }
                    XCTAssertEqual(try cursor.next()!!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FetchedType>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(statement), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
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
                func test(_ cursor: DatabaseCursor<FetchedType?>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 21 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT throw() UNION ALL SELECT 2"
                    try test(Optional<FetchedType>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<FetchedType?>, sql: String) throws {
                    do {
                        _ = try cursor()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Optional<FetchedType>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchCursor(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchCursor(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [FetchedType?]) {
                    XCTAssertEqual(array.count, 2)
                    XCTAssertEqual(array[0]!.int, 1)
                    XCTAssertTrue(array[1] == nil)
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FetchedType>.fetchAll(db, sql))
                    try test(Optional<FetchedType>.fetchAll(statement))
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql)))
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchAll(db))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchAll(db, sql, adapter: adapter))
                    try test(Optional<FetchedType>.fetchAll(statement, adapter: adapter))
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)))
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchAll(db))
                }
            }
        }
    }
    
    func testOptionalFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FetchedType?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FetchedType.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FetchedType.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FetchedType>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(statement), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [FetchedType?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "\(customError)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: \(customError)")
                    }
                }
                do {
                    let sql = "SELECT throw()"
                    try test(Optional<FetchedType>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FetchedType?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "no such table: nonExistingTable")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: no such table: nonExistingTable")
                    }
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    try test(Optional<FetchedType>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql)), sql: sql)
                    try test(SQLFetchRequest(sql: sql).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FetchedType>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FetchedType>.fetchAll(db, SQLFetchRequest(sql: sql, adapter: adapter)), sql: sql)
                    try test(SQLFetchRequest(sql: sql, adapter: adapter).bound(to: Optional<FetchedType>.self).fetchAll(db), sql: sql)
                }
            }
        }
    }
}
