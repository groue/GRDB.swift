import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Fetched {
    var firstName: String
    var lastName: String
}

extension Fetched : FetchableRecord {
    init(row: Row) {
        firstName = row["firstName"]
        lastName = row["lastName"]
    }
}

class FetchableRecordTests: GRDBTestCase {

    func testRowInitializer() {
        let row = Row(["firstName": "Arthur", "lastName": "Martin"])
        let s = Fetched(row: row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
    }
    
    func testFetchCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: RecordCursor<Fetched>) throws {
                var record = try cursor.next()!
                XCTAssertEqual(record.firstName, "Arthur")
                XCTAssertEqual(record.lastName, "Martin")
                record = try cursor.next()!
                XCTAssertEqual(record.firstName, "Barbara")
                XCTAssertEqual(record.lastName, "Gourde")
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            do {
                let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Fetched.fetchCursor(db, sql: sql))
                try test(Fetched.fetchCursor(statement))
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched>(sql: sql).fetchCursor(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
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
            let request: SQLRequest<Fetched> = """
                SELECT \("Arthur") AS firstName, \("O'Brien") AS lastName
                """
            let cursor = try request.fetchCursor(db)
            let fetched = try cursor.next()!
            XCTAssertEqual(fetched.firstName, "Arthur")
            XCTAssertEqual(fetched.lastName, "O'Brien")
        }
    }
    #endif
    
    func testFetchCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            func test(_ cursor: RecordCursor<Fetched>, sql: String) throws {
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
                let sql = "SELECT throw(), NULL"
                try test(Fetched.fetchCursor(db, sql: sql), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql: sql)), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Fetched>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw(), NULL"
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
            func test(_ cursor: @autoclosure () throws -> RecordCursor<Fetched>, sql: String) throws {
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
                XCTAssertEqual(array.map { $0.firstName }, ["Arthur", "Barbara"])
                XCTAssertEqual(array.map { $0.lastName }, ["Martin", "Gourde"])
            }
            do {
                let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                let statement = try db.makeSelectStatement(sql: sql)
                try test(Fetched.fetchAll(db, sql: sql))
                try test(Fetched.fetchAll(statement))
                try test(Fetched.fetchAll(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Fetched>(sql: sql).fetchAll(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
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
            let request: SQLRequest<Fetched> = """
                SELECT \("Arthur") AS firstName, \("O'Brien") AS lastName
                """
            let array = try request.fetchAll(db)
            XCTAssertEqual(array[0].firstName, "Arthur")
            XCTAssertEqual(array[0].lastName, "O'Brien")
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
                func test(_ record: Fetched?) {
                    XCTAssertEqual(record!.firstName, "Arthur")
                    XCTAssertEqual(record!.lastName, "Martin")
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName"
                    let statement = try db.makeSelectStatement(sql: sql)
                    try test(Fetched.fetchOne(db, sql: sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Fetched>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName"
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
            let request: SQLRequest<Fetched> = """
                SELECT \("Arthur") AS firstName, \("O'Brien") AS lastName
                """
            let fetched = try request.fetchOne(db)
            XCTAssertEqual(fetched!.firstName, "Arthur")
            XCTAssertEqual(fetched!.lastName, "O'Brien")
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
}
