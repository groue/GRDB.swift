import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

#if !USING_BUILTIN_SQLITE
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #elseif os(watchOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteWatchSimulator
        #else
            import SQLiteWatchOS
        #endif
    #endif
#endif

// A type that adopts DatabaseValueConvertible and StatementColumnConvertible
private struct FastWrappedInt: DatabaseValueConvertible, StatementColumnConvertible {
    let int: Int
    let fast: Bool
    
    init(int: Int, fast: Bool) {
        self.int = int
        self.fast = fast
    }
    
    init(sqliteStatement: SQLiteStatement, index: Int32) {
        self.init(int: Int(sqlite3_column_int64(sqliteStatement, index)), fast: true)
    }
    
    var databaseValue: DatabaseValue {
        return int.databaseValue
    }
    
    static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> FastWrappedInt? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return FastWrappedInt(int: int, fast: false)
    }
}

private struct Request : FetchRequest {
    let statement: () throws -> SelectStatement
    let adapter: RowAdapter?
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return (try statement(), adapter)
    }
}

class StatementColumnConvertibleFetchTests: GRDBTestCase {
    
    func testSlowConversion() {
        let slow = FastWrappedInt.fromDatabaseValue(0.databaseValue)!
        XCTAssertEqual(slow.int, 0)
        XCTAssertEqual(slow.fast, false)
    }
    
    func testRowExtraction() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var rows = try Row.fetchCursor(db, "SELECT NULL")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertTrue(one == nil)
                }
                rows = try Row.fetchCursor(db, "SELECT 1")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(atIndex: 0)
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1 AS int")
                while let row = try rows.next() {
                    let one: FastWrappedInt? = row.value(named: "int")
                    XCTAssertEqual(one!.int, 1)
                    XCTAssertEqual(one!.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1")
                while let row = try rows.next() {
                    let one: FastWrappedInt = row.value(atIndex: 0)
                    XCTAssertEqual(one.int, 1)
                    XCTAssertEqual(one.fast, true)
                }
                rows = try Row.fetchCursor(db, "SELECT 1 AS int")
                while let row = try rows.next() {
                    let one: FastWrappedInt = row.value(named: "int")
                    XCTAssertEqual(one.int, 1)
                    XCTAssertEqual(one.fast, true)
                }
            }
        }
    }
    
    // MARK: - StatementColumnConvertible.fetch
    
    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FastWrappedInt>) throws {
                    var i = try cursor.next()!
                    XCTAssertEqual(i.int, 1)
                    XCTAssertTrue(i.fast)
                    i = try cursor.next()!
                    XCTAssertEqual(i.int, 2)
                    XCTAssertTrue(i.fast)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FastWrappedInt.fetchCursor(db, sql))
                    try test(FastWrappedInt.fetchCursor(statement))
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchCursor(db, sql, adapter: adapter))
                    try test(FastWrappedInt.fetchCursor(statement, adapter: adapter))
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FastWrappedInt>, sql: String) throws {
                    var i = try cursor.next()!
                    XCTAssertEqual(i.int, 1)
                    XCTAssertTrue(i.fast)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(FastWrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(FastWrappedInt.self)")
                    }
                    i = try cursor.next()!
                    XCTAssertEqual(i.int, 0)    // SQLite conversion from 'foo' to 0
                    XCTAssertTrue(i.fast)
                    i = try cursor.next()!
                    XCTAssertEqual(i.int, 2)
                    XCTAssertTrue(i.fast)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FastWrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchCursor(statement), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ cursor: DatabaseCursor<FastWrappedInt>, sql: String) throws {
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
                    try test(FastWrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, throw() UNION ALL SELECT 0, 2"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<FastWrappedInt>, sql: String) throws {
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
                    try test(FastWrappedInt.fetchCursor(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [FastWrappedInt]) {
                    XCTAssertEqual(array.map { $0.int }, [1,2])
                    XCTAssertEqual(array.map { $0.fast }, [true, true])
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FastWrappedInt.fetchAll(db, sql))
                    try test(FastWrappedInt.fetchAll(statement))
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchAll(db, sql, adapter: adapter))
                    try test(FastWrappedInt.fetchAll(statement, adapter: adapter))
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    func testFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FastWrappedInt], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value NULL to \(FastWrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value NULL to \(FastWrappedInt.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(FastWrappedInt.fetchAll(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchAll(statement), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [FastWrappedInt], sql: String) throws {
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
                    try test(FastWrappedInt.fetchAll(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FastWrappedInt], sql: String) throws {
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
                    try test(FastWrappedInt.fetchAll(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: FastWrappedInt?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FastWrappedInt.fetchOne(db, sql))
                        try test(FastWrappedInt.fetchOne(statement))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FastWrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(statement, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ nilBecauseNull: FastWrappedInt?) {
                        XCTAssertTrue(nilBecauseNull == nil)
                    }
                    do {
                        let sql = "SELECT NULL"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FastWrappedInt.fetchOne(db, sql))
                        try test(FastWrappedInt.fetchOne(statement))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, NULL"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FastWrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(statement, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ value: FastWrappedInt?) {
                        XCTAssertEqual(value!.int, 1)
                    }
                    do {
                        let sql = "SELECT 1"
                        let statement = try db.makeSelectStatement(sql)
                        try test(FastWrappedInt.fetchOne(db, sql))
                        try test(FastWrappedInt.fetchOne(statement))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(FastWrappedInt.fetchOne(db, sql, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(statement, adapter: adapter))
                        try test(FastWrappedInt.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
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
                func test(_ value: @autoclosure () throws -> FastWrappedInt?, sql: String) throws {
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
                    try test(FastWrappedInt.fetchOne(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> FastWrappedInt?, sql: String) throws {
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
                    try test(FastWrappedInt.fetchOne(db, sql), sql: sql)
                    try test(FastWrappedInt.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(FastWrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(FastWrappedInt.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(FastWrappedInt.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    // MARK: - Optional<StatementColumnConvertible>.fetch
    
    func testOptionalFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FastWrappedInt?>) throws {
                    let i = try cursor.next()!
                    XCTAssertEqual(i!.int, 1)
                    // XCTAssertTrue(i!.fast) // TODO: uncomment when we have a workaround for rdar://22852669
                    XCTAssertTrue(try cursor.next()! == nil)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql))
                    try test(Optional<FastWrappedInt>.fetchCursor(statement))
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql, adapter: adapter))
                    try test(Optional<FastWrappedInt>.fetchCursor(statement, adapter: adapter))
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    // TODO: this test will become invalid when we have a workaround for
    // rdar://22852669, since there is can't be any conversion failure with
    // the sqlite3_column_xxx function family.
    func testOptionalFetchCursorConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<FastWrappedInt?>, sql: String) throws {
                    var i = try cursor.next()!
                    XCTAssertEqual(i!.int, 1)
                    XCTAssertTrue(try cursor.next()! == nil)
                    do {
                        _ = try cursor.next()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FastWrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FastWrappedInt.self)")
                    }
                    i = try cursor.next()!
                    XCTAssertEqual(i!.int, 2)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(statement), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(statement, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<FastWrappedInt?>, sql: String) throws {
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
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [FastWrappedInt?]) {
                    XCTAssertEqual(array.count, 2)
                    XCTAssertEqual(array[0]!.int, 1)
                    // XCTAssertTrue(array[0]!.fast) // TODO: uncomment when we have a workaround for rdar://22852669
                    XCTAssertTrue(array[1] == nil)
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql))
                    try test(Optional<FastWrappedInt>.fetchAll(statement))
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql, adapter: adapter))
                    try test(Optional<FastWrappedInt>.fetchAll(statement, adapter: adapter))
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
                }
            }
        }
    }
    
    // TODO: this test will become invalid when we have a workaround for
    // rdar://22852669, since there is can't be any conversion failure with
    // the sqlite3_column_xxx function family.
    func testOptionalFetchAllConversionFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FastWrappedInt?], sql: String) throws {
                    do {
                        _ = try array()
                        XCTFail()
                    } catch let error as DatabaseError {
                        XCTAssertEqual(error.code, 1) // SQLITE_ERROR
                        XCTAssertEqual(error.message, "could not convert database value \"foo\" to \(FastWrappedInt.self)")
                        XCTAssertEqual(error.sql!, sql)
                        XCTAssertEqual(error.description, "SQLite error 1 with statement `\(sql)`: could not convert database value \"foo\" to \(FastWrappedInt.self)")
                    }
                }
                do {
                    let sql = "SELECT 1 UNION ALL SELECT NULL UNION ALL SELECT 'foo' UNION ALL SELECT 2"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(statement), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL UNION ALL SELECT 0, 'foo' UNION ALL SELECT 0, 2"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(statement, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { statement }, adapter: adapter)), sql: sql)
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
                func test(_ array: @autoclosure () throws -> [FastWrappedInt?], sql: String) throws {
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
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testOptionalFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [FastWrappedInt?], sql: String) throws {
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
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Optional<FastWrappedInt>.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Optional<FastWrappedInt>.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
}
