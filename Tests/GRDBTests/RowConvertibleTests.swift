import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Fetched {
    var firstName: String
    var lastName: String
}

extension Fetched : RowConvertible {
    init(row: Row) {
        firstName = row["firstName"]
        lastName = row["lastName"]
    }
}

class RowConvertibleTests: GRDBTestCase {

    func testRowInitializer() {
        let row = Row(["firstName": "Arthur", "lastName": "Martin"])
        let s = Fetched(row: row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
    }
    
    func testFetchCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: DatabaseCursor<Fetched>) throws {
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
                let statement = try db.makeSelectStatement(sql)
                try test(Fetched.fetchCursor(db, sql))
                try test(Fetched.fetchCursor(statement))
                try test(Fetched.fetchCursor(db, SQLRequest(sql)))
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchCursor(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                let statement = try db.makeSelectStatement(sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql, adapter: adapter))
                try test(Fetched.fetchCursor(statement, adapter: adapter))
                try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)))
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchCursor(db))
            }
        }
    }

    func testFetchCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            func test(_ cursor: DatabaseCursor<Fetched>, sql: String) throws {
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
                let sql = "SELECT throw(), NULL"
                try test(Fetched.fetchCursor(db, sql), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest(sql)), sql: sql)
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw(), NULL"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchCursor(db), sql: sql)
            }
        }
    }

    func testFetchCursorCompilationFailure() throws {
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
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchCursor(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchCursor(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchCursor(db), sql: sql)
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
                let statement = try db.makeSelectStatement(sql)
                try test(Fetched.fetchAll(db, sql))
                try test(Fetched.fetchAll(statement))
                try test(Fetched.fetchAll(db, SQLRequest(sql)))
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchAll(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                let statement = try db.makeSelectStatement(sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql, adapter: adapter))
                try test(Fetched.fetchAll(statement, adapter: adapter))
                try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)))
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchAll(db))
            }
        }
    }

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
                try test(Fetched.fetchAll(db, sql), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest(sql)), sql: sql)
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchAll(db), sql: sql)
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
                try test(Fetched.fetchAll(db, sql), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest(sql)), sql: sql)
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchAll(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchAll(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchAll(db), sql: sql)
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
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchOne(db, sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0, 1 WHERE 0"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql, adapter: adapter))
                    try test(Fetched.fetchOne(statement, adapter: adapter))
                    try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchOne(db))
                }
            }
            do {
                func test(_ record: Fetched?) {
                    XCTAssertEqual(record!.firstName, "Arthur")
                    XCTAssertEqual(record!.lastName, "Martin")
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Fetched.fetchOne(db, sql))
                    try test(Fetched.fetchOne(statement))
                    try test(Fetched.fetchOne(db, SQLRequest(sql)))
                    try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Fetched.fetchOne(db, sql, adapter: adapter))
                    try test(Fetched.fetchOne(statement, adapter: adapter))
                    try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)))
                    try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchOne(db))
                }
            }
        }
    }

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
                try test(Fetched.fetchOne(db, sql), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest(sql)), sql: sql)
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchOne(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchOne(db), sql: sql)
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
                try test(Fetched.fetchOne(db, sql), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest(sql)), sql: sql)
                try test(SQLRequest(sql).asRequest(of: Fetched.self).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Fetched.fetchOne(db, sql, adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                try test(Fetched.fetchOne(db, SQLRequest(sql, adapter: adapter)), sql: sql)
                try test(SQLRequest(sql, adapter: adapter).asRequest(of: Fetched.self).fetchOne(db), sql: sql)
            }
        }
    }
}
