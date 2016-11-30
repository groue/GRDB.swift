import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Request : FetchRequest {
    let statement: () throws -> SelectStatement
    let adapter: RowAdapter?
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return (try statement(), adapter)
    }
}

class RowFetchTests: GRDBTestCase {

    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<Row>) throws {
                    var row = try cursor.next()!
                    XCTAssertEqual(row.value(named: "firstName") as String, "Arthur")
                    XCTAssertEqual(row.value(named: "lastName") as String, "Martin")
                    row = try cursor.next()!
                    XCTAssertEqual(row.value(named: "firstName") as String, "Barbara")
                    XCTAssertEqual(row.value(named: "lastName") as String, "Gourde")
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Row.fetchCursor(db, sql))
                    try test(Row.fetchCursor(statement))
                    try test(Row.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchCursor(db, sql, adapter: adapter))
                    try test(Row.fetchCursor(statement, adapter: adapter))
                    try test(Row.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ cursor: DatabaseCursor<Row>, sql: String) throws {
                    let row = try cursor.next()!
                    XCTAssertEqual(row.value(named: "firstName") as String, "Arthur")
                    XCTAssertEqual(row.value(named: "lastName") as String, "Martin")
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
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT throw(), NULL"
                    try test(Row.fetchCursor(db, sql), sql: sql)
                    try test(Row.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, throw(), NULL"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<Row>, sql: String) throws {
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
                    try test(Row.fetchCursor(db, sql), sql: sql)
                    try test(Row.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [Row]) {
                    XCTAssertEqual(array.map { $0.value(named: "firstName") as String }, ["Arthur", "Barbara"])
                    XCTAssertEqual(array.map { $0.value(named: "lastName") as String }, ["Martin", "Gourde"])
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(Row.fetchAll(db, sql))
                    try test(Row.fetchAll(statement))
                    try test(Row.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchAll(db, sql, adapter: adapter))
                    try test(Row.fetchAll(statement, adapter: adapter))
                    try test(Row.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ array: @autoclosure () throws -> [Row], sql: String) throws {
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
                    try test(Row.fetchAll(db, sql), sql: sql)
                    try test(Row.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [Row], sql: String) throws {
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
                    try test(Row.fetchAll(db, sql), sql: sql)
                    try test(Row.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: Row?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(Row.fetchOne(db, sql))
                        try test(Row.fetchOne(statement))
                        try test(Row.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(Row.fetchOne(db, sql, adapter: adapter))
                        try test(Row.fetchOne(statement, adapter: adapter))
                        try test(Row.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ row: Row?) {
                        XCTAssertEqual(row!.value(named: "firstName") as String, "Arthur")
                        XCTAssertEqual(row!.value(named: "lastName") as String, "Martin")
                    }
                    do {
                        let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName"
                        let statement = try db.makeSelectStatement(sql)
                        try test(Row.fetchOne(db, sql))
                        try test(Row.fetchOne(statement))
                        try test(Row.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(Row.fetchOne(db, sql, adapter: adapter))
                        try test(Row.fetchOne(statement, adapter: adapter))
                        try test(Row.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ value: @autoclosure () throws -> Row?, sql: String) throws {
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
                    try test(Row.fetchOne(db, sql), sql: sql)
                    try test(Row.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> Row?, sql: String) throws {
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
                    try test(Row.fetchOne(db, sql), sql: sql)
                    try test(Row.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(Row.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(Row.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(Row.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
}
