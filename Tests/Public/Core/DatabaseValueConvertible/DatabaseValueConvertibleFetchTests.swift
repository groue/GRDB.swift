import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A type that adopts DatabaseValueConvertible but does not adopt StatementColumnConvertible
private struct WrappedInt: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> WrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return WrappedInt(int: int)
    }
}

private struct Request : FetchRequest {
    let statement: () throws -> SelectStatement
    let adapter: RowAdapter?
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return (try statement(), adapter)
    }
}

class DatabaseValueConvertibleFetchTests: GRDBTestCase {
    
    // MARK: - DatabaseValueConvertible.fetch
    
    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<WrappedInt>) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchCursor(db, sql))
                    try test(WrappedInt.fetchCursor(statement))
                    try test(WrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchCursor(db, sql, adapter: adapter))
                    try test(WrappedInt.fetchCursor(statement, adapter: adapter))
                    try test(WrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<WrappedInt>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!.int, 1)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(WrappedInt.self)")
                    }
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(WrappedInt.self)")
                    }
                    XCTAssertEqual(try cursor.next()!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(WrappedInt.fetchCursor(statement), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ cursor: DatabaseCursor<WrappedInt>, sql: String) throws {
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
                    try test(WrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(WrappedInt.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<WrappedInt>, sql: String) throws {
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
                    try test(WrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(WrappedInt.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [WrappedInt]) {
                    XCTAssertEqual(array.map { $0.int }, [1,2])
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchAll(db, sql))
                    try test(WrappedInt.fetchAll(statement))
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchAll(db, sql, adapter: adapter))
                    try test(WrappedInt.fetchAll(statement, adapter: adapter))
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [WrappedInt], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(WrappedInt.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchAll(db, sql), sql: sql)
                    try test(WrappedInt.fetchAll(statement), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [WrappedInt], sql: String) throws {
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
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchAll(db, sql), sql: sql)
                    try test(WrappedInt.fetchAll(statement), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [WrappedInt], sql: String) throws {
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
                    try test(WrappedInt.fetchAll(db, sql), sql: sql)
                    try test(WrappedInt.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: WrappedInt?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(WrappedInt.fetchOne(db, sql))
                        try test(WrappedInt.fetchOne(statement))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(WrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(WrappedInt.fetchOne(statement, adapter: adapter))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ nilBecauseNull: WrappedInt?) {
                        XCTAssertTrue(nilBecauseNull == nil)
                    }
                    do {
                        let sql = "SELECT NULL"
                        let statement = try db.makeSelectStatement(sql)
                        try test(WrappedInt.fetchOne(db, sql))
                        try test(WrappedInt.fetchOne(statement))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, NULL"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(WrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(WrappedInt.fetchOne(statement, adapter: adapter))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ value: WrappedInt?) {
                        XCTAssertEqual(value!.int, 1)
                    }
                    do {
                        let sql = "SELECT 1"
                        let statement = try db.makeSelectStatement(sql)
                        try test(WrappedInt.fetchOne(db, sql))
                        try test(WrappedInt.fetchOne(statement))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(WrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(WrappedInt.fetchOne(statement, adapter: adapter))
                        try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
            }
        }
    }
    
    func testFetchOneConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> WrappedInt?, sql: String) throws {
                    do {
                        _ = try value()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(WrappedInt.self)")
                    }
                }
                do {
                    let sql = "SELECT 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchOne(db, sql), sql: sql)
                    try test(WrappedInt.fetchOne(statement), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 'foo'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(statement, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ value: @autoclosure () throws -> WrappedInt?, sql: String) throws {
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
                    let statement = try db.makeSelectStatement(sql)
                    try test(WrappedInt.fetchOne(db, sql), sql: sql)
                    try test(WrappedInt.fetchOne(statement), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(statement, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> WrappedInt?, sql: String) throws {
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
                    try test(WrappedInt.fetchOne(db, sql), sql: sql)
                    try test(WrappedInt.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(WrappedInt.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(WrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    // MARK: - Optional<DatabaseValueConvertible>.fetch
    
    func testOptionalFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<WrappedInt?>) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql))
                    try test(Optional<WrappedInt>.fetchCursor(statement))
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql, adapter: adapter))
                    try test(Optional<WrappedInt>.fetchCursor(statement, adapter: adapter))
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testOptionalFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<WrappedInt?>, sql: String) throws {
                    XCTAssertEqual(try cursor.next()!!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(WrappedInt.self)")
                    }
                    XCTAssertEqual(try cursor.next()!!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(statement), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ cursor: DatabaseCursor<WrappedInt?>, sql: String) throws {
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
                    try test(Optional<WrappedInt>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<WrappedInt?>, sql: String) throws {
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
                    try test(Optional<WrappedInt>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [WrappedInt?]) {
                    XCTAssertEqual(array.count, 2)
                    XCTAssertEqual(array[0]!.int, 1)
                    XCTAssertTrue(array[1] == nil)
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<WrappedInt>.fetchAll(db, sql))
                    try test(Optional<WrappedInt>.fetchAll(statement))
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchAll(db, sql, adapter: adapter))
                    try test(Optional<WrappedInt>.fetchAll(statement, adapter: adapter))
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testOptionalFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [WrappedInt?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(WrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(WrappedInt.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<WrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(statement), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [WrappedInt?], sql: String) throws {
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
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<WrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(statement), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [WrappedInt?], sql: String) throws {
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
                    try test(Optional<WrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<WrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<WrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
}
