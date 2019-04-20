import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if GRDBCIPHER
        import SQLCipher
    #elseif SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

// A type that adopts DatabaseValueConvertible and StatementColumnConvertible
private struct Fetched: DatabaseValueConvertible, StatementColumnConvertible {
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
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Fetched? {
        guard let int = Int.fromDatabaseValue(dbValue) else {
            return nil
        }
        return Fetched(int: int, fast: false)
    }
}

class StatementColumnConvertibleFetchTests: GRDBTestCase {
    
    func testSlowConversion() {
        let slow = Fetched.fromDatabaseValue(0.databaseValue)!
        XCTAssertEqual(slow.int, 0)
        XCTAssertEqual(slow.fast, false)
    }
    
    func testRowExtraction() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var rows = try Row.fetchCursor(db, sql: "SELECT NULL")
            while let row = try rows.next() {
                let one: Fetched? = row[0]
                XCTAssertTrue(one == nil)
            }
            rows = try Row.fetchCursor(db, sql: "SELECT 1")
            while let row = try rows.next() {
                let one: Fetched? = row[0]
                XCTAssertEqual(one!.int, 1)
                XCTAssertEqual(one!.fast, true)
            }
            rows = try Row.fetchCursor(db, sql: "SELECT 1 AS int")
            while let row = try rows.next() {
                let one: Fetched? = row["int"]
                XCTAssertEqual(one!.int, 1)
                XCTAssertEqual(one!.fast, true)
            }
            rows = try Row.fetchCursor(db, sql: "SELECT 1")
            while let row = try rows.next() {
                let one: Fetched = row[0]
                XCTAssertEqual(one.int, 1)
                XCTAssertEqual(one.fast, true)
            }
            rows = try Row.fetchCursor(db, sql: "SELECT 1 AS int")
            while let row = try rows.next() {
                let one: Fetched = row["int"]
                XCTAssertEqual(one.int, 1)
                XCTAssertEqual(one.fast, true)
            }
        }
    }

    // MARK: - StatementColumnConvertible.fetch

    func testFetchCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: FastDatabaseValueCursor<Fetched>) throws {
                var i = try cursor.next()!
                XCTAssertEqual(i.int, 1)
                XCTAssertTrue(i.fast)
                i = try cursor.next()!
                XCTAssertEqual(i.int, 2)
                XCTAssertTrue(i.fast)
                XCTAssertTrue(try cursor.next() == nil) // end
                XCTAssertTrue(try cursor.next() == nil) // past the end
            }
            do {
                let sql = "SELECT 1 UNION ALL SELECT 2"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Fetched.fetchCursor(db, sql: sql))
                try test(Fetched.fetchCursor(statement))
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched>(sql: sql).fetchCursor(db))
            }
            do {
                let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                let statement = try db.makeSelectStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql: sql, adapter: adapter))
                try test(Fetched.fetchCursor(statement, adapter: adapter))
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchCursor(db))
            }
        }
    }
    
    #if swift(>=5.0)
    func testFetchCursorWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Fetched> = "SELECT \(42)"
            let cursor = try request.fetchCursor(db)
            let fetched = try cursor.next()!
            XCTAssertEqual(fetched.int, 42)
            XCTAssertTrue(fetched.fast)
        }
    }
    #endif
    
    func testFetchCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            func test(_ cursor: FastDatabaseValueCursor<Fetched>, sql: String) throws {
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
                } catch is DatabaseError {
                    // Various SQLite and SQLCipher versions don't emit the same
                    // error. What we care about is that there is an error.
                }
            }
            do {
                let sql = "SELECT throw()"
                try test(Fetched.fetchCursor(db, sql: sql), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchCursor(db), sql: sql)
            }
        }
    }

    func testFetchCursorCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: @autoclosure () throws -> FastDatabaseValueCursor<Fetched>, sql: String) throws {
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
                try test(Fetched.fetchCursor(db, sql: sql), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchCursor(db), sql: sql)
            }
        }
    }

    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ array: [Fetched]) {
                XCTAssertEqual(array.map { $0.int }, [1,2])
                XCTAssertEqual(array.map { $0.fast }, [true, true])
            }
            do {
                let sql = "SELECT 1 UNION ALL SELECT 2"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Fetched.fetchAll(db, sql: sql))
                try test(Fetched.fetchAll(statement))
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched>(sql: sql).fetchAll(db))
            }
            do {
                let sql = "SELECT 0, 1 UNION ALL SELECT 0, 2"
                let statement = try db.makeSelectStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql: sql, adapter: adapter))
                try test(Fetched.fetchAll(statement, adapter: adapter))
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchAll(db))
            }
        }
    }
    
    #if swift(>=5.0)
    func testFetchAllWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Fetched> = "SELECT \(42)"
            let array = try request.fetchAll(db)
            XCTAssertEqual(array[0].int, 42)
            XCTAssertTrue(array[0].fast)
        }
    }
    #endif
    
    func testFetchAllStepFailure() throws {
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
                try test(Fetched.fetchAll(db, sql: sql), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }

    func testFetchAllCompilationFailure() throws {
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
                try test(Fetched.fetchAll(db, sql: sql), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }

    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                func test(_ nilBecauseMissingRow: Fetched?) {
                    XCTAssertTrue(nilBecauseMissingRow == nil)
                }
                do {
                    let sql = "SELECT 1 WHERE 0"
                    let statement = try db.makeSelectStatement(sql: sql)
                    try test(Fetched.fetchOne(db, sql: sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Fetched>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0, 1 WHERE 0"
                    let statement = try db.makeSelectStatement(sql: sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql: sql, adapter: adapter))
                    try test(Fetched.fetchOne(statement, adapter: adapter))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                    try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchOne(db))
                }
            }
            do {
                func test(_ nilBecauseNull: Fetched?) {
                    XCTAssertTrue(nilBecauseNull == nil)
                }
                do {
                    let sql = "SELECT NULL"
                    let statement = try db.makeSelectStatement(sql: sql)
                    try test(Fetched.fetchOne(db, sql: sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Fetched>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0, NULL"
                    let statement = try db.makeSelectStatement(sql: sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql: sql, adapter: adapter))
                    try test(Fetched.fetchOne(statement, adapter: adapter))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                    try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchOne(db))
                }
            }
            do {
                func test(_ value: Fetched?) {
                    XCTAssertEqual(value!.int, 1)
                }
                do {
                    let sql = "SELECT 1"
                    let statement = try db.makeSelectStatement(sql: sql)
                    try test(Fetched.fetchOne(db, sql: sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Fetched>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0, 1"
                    let statement = try db.makeSelectStatement(sql: sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql: sql, adapter: adapter))
                    try test(Fetched.fetchOne(statement, adapter: adapter))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                    try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchOne(db))
                }
            }
        }
    }
    
    #if swift(>=5.0)
    func testFetchOneWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Fetched> = "SELECT \(42)"
            let fetched = try request.fetchOne(db)
            XCTAssertEqual(fetched!.int, 42)
            XCTAssertTrue(fetched!.fast)
        }
    }
    #endif
    
    func testFetchOneStepFailure() throws {
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
                try test(Fetched.fetchOne(db, sql: sql), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchOne(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchOne(db), sql: sql)
            }
        }
    }

    func testFetchOneCompilationFailure() throws {
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
                try test(Fetched.fetchOne(db, sql: sql), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchOne(db, sql: sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql, adapter: adapter).fetchOne(db), sql: sql)
            }
        }
    }

    // MARK: - Optional<StatementColumnConvertible>.fetch

    func testOptionalFetchCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: FastNullableDatabaseValueCursor<Fetched>) throws {
                let i = try cursor.next()!
                XCTAssertEqual(i!.int, 1)
                XCTAssertTrue(i!.fast)
                XCTAssertTrue(try cursor.next()! == nil)
                XCTAssertTrue(try cursor.next() == nil) // end
                XCTAssertTrue(try cursor.next() == nil) // past the end
            }
            do {
                let sql = "SELECT 1 UNION ALL SELECT NULL"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Optional<Fetched>.fetchCursor(db, sql: sql))
                try test(Optional<Fetched>.fetchCursor(statement))
                try test(Optional<Fetched>.fetchCursor(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched?>(sql: sql).fetchCursor(db))
            }
            do {
                let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                let statement = try db.makeSelectStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Optional<Fetched>.fetchCursor(db, sql: sql, adapter: adapter))
                try test(Optional<Fetched>.fetchCursor(statement, adapter: adapter))
                try test(Optional<Fetched>.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Fetched?>(sql: sql, adapter: adapter).fetchCursor(db))
            }
        }
    }
    
    #if swift(>=5.0)
    func testOptionalFetchCursorWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Fetched?> = "SELECT \(42)"
            let cursor = try request.fetchCursor(db)
            let fetched = try cursor.next()!
            XCTAssertEqual(fetched!.int, 42)
            XCTAssert(fetched!.fast)
        }
    }
    #endif
    
    func testOptionalFetchCursorCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: @autoclosure () throws -> FastNullableDatabaseValueCursor<Fetched>, sql: String) throws {
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
                try test(Optional<Fetched>.fetchCursor(db, sql: sql), sql: sql)
                try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Optional<Fetched>.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Optional<Fetched>.fetchCursor(db, sql: sql, adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchCursor(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql, adapter: adapter).fetchCursor(db), sql: sql)
            }
        }
    }

    func testOptionalFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ array: [Fetched?]) {
                XCTAssertEqual(array.count, 2)
                XCTAssertEqual(array[0]!.int, 1)
                XCTAssertTrue(array[0]!.fast)
                XCTAssertTrue(array[1] == nil)
            }
            do {
                let sql = "SELECT 1 UNION ALL SELECT NULL"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Optional<Fetched>.fetchAll(db, sql: sql))
                try test(Optional<Fetched>.fetchAll(statement))
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched?>(sql: sql).fetchAll(db))
            }
            do {
                let sql = "SELECT 0, 1 UNION ALL SELECT 0, NULL"
                let statement = try db.makeSelectStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Optional<Fetched>.fetchAll(db, sql: sql, adapter: adapter))
                try test(Optional<Fetched>.fetchAll(statement, adapter: adapter))
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Fetched?>(sql: sql, adapter: adapter).fetchAll(db))
            }
        }
    }
    
    #if swift(>=5.0)
    func testOptionalFetchAllWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Fetched?> = "SELECT \(42)"
            let array = try request.fetchAll(db)
            XCTAssertEqual(array[0]!.int, 42)
            XCTAssert(array[0]!.fast)
        }
    }
    #endif
    
    func testOptionalFetchAllStepFailure() throws {
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
                try test(Optional<Fetched>.fetchAll(db, sql: sql), sql: sql)
                try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Optional<Fetched>.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }

    func testOptionalFetchAllCompilationFailure() throws {
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
                try test(Optional<Fetched>.fetchAll(db, sql: sql), sql: sql)
                try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Optional<Fetched>.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchAll(db.makeSelectStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Optional<Fetched>.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Fetched?>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }
}
