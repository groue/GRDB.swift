import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct SimpleRowConvertible {
    var firstName: String
    var lastName: String
    var isFetched: Bool = false
}

extension SimpleRowConvertible : RowConvertible {
    init(row: Row) {
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        isFetched = false
    }
    
    mutating func awakeFromFetch(row: Row) {
        isFetched = true
    }
}

private struct Request : FetchRequest {
    let statement: () throws -> SelectStatement
    let adapter: RowAdapter?
    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
        return (try statement(), adapter)
    }
}

class RowConvertibleTests: GRDBTestCase {

    func testRowInitializer() {
        let row = Row(["firstName": "Arthur", "lastName": "Martin"])
        let s = SimpleRowConvertible(row: row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
        XCTAssertFalse(s.isFetched)
    }
    
    func testFetchCursor() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: DatabaseCursor<SimpleRowConvertible>) throws {
                    var record = try cursor.next()!
                    XCTAssertEqual(record.firstName, "Arthur")
                    XCTAssertEqual(record.lastName, "Martin")
                    XCTAssertTrue(record.isFetched)
                    record = try cursor.next()!
                    XCTAssertEqual(record.firstName, "Barbara")
                    XCTAssertEqual(record.lastName, "Gourde")
                    XCTAssertTrue(record.isFetched)
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(SimpleRowConvertible.fetchCursor(db, sql))
                    try test(SimpleRowConvertible.fetchCursor(statement))
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchCursor(db, sql, adapter: adapter))
                    try test(SimpleRowConvertible.fetchCursor(statement, adapter: adapter))
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ cursor: DatabaseCursor<SimpleRowConvertible>, sql: String) throws {
                    let record = try cursor.next()!
                    XCTAssertEqual(record.firstName, "Arthur")
                    XCTAssertEqual(record.lastName, "Martin")
                    XCTAssertTrue(record.isFetched)
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
                    try test(SimpleRowConvertible.fetchCursor(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, throw(), NULL"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchCursorCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ cursor: @autoclosure () throws -> DatabaseCursor<SimpleRowConvertible>, sql: String) throws {
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
                    try test(SimpleRowConvertible.fetchCursor(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchCursor(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchCursor(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: [SimpleRowConvertible]) {
                    XCTAssertEqual(array.map { $0.firstName }, ["Arthur", "Barbara"])
                    XCTAssertEqual(array.map { $0.lastName }, ["Martin", "Gourde"])
                    XCTAssertEqual(array.map { $0.isFetched }, [true, true])
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    try test(SimpleRowConvertible.fetchAll(db, sql))
                    try test(SimpleRowConvertible.fetchAll(statement))
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { statement }, adapter: nil)))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                    let statement = try db.makeSelectStatement(sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchAll(db, sql, adapter: adapter))
                    try test(SimpleRowConvertible.fetchAll(statement, adapter: adapter))
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ array: @autoclosure () throws -> [SimpleRowConvertible], sql: String) throws {
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
                    try test(SimpleRowConvertible.fetchAll(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchAllCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ array: @autoclosure () throws -> [SimpleRowConvertible], sql: String) throws {
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
                    try test(SimpleRowConvertible.fetchAll(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchAll(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchAll(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOne() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    func test(_ nilBecauseMissingRow: SimpleRowConvertible?) {
                        XCTAssertTrue(nilBecauseMissingRow == nil)
                    }
                    do {
                        let sql = "SELECT 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        try test(SimpleRowConvertible.fetchOne(db, sql))
                        try test(SimpleRowConvertible.fetchOne(statement))
                        try test(SimpleRowConvertible.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0, 1 WHERE 0"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(SimpleRowConvertible.fetchOne(db, sql, adapter: adapter))
                        try test(SimpleRowConvertible.fetchOne(statement, adapter: adapter))
                        try test(SimpleRowConvertible.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
                    }
                }
                do {
                    func test(_ record: SimpleRowConvertible?) {
                        XCTAssertEqual(record!.firstName, "Arthur")
                        XCTAssertEqual(record!.lastName, "Martin")
                        XCTAssertTrue(record!.isFetched)
                    }
                    do {
                        let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName"
                        let statement = try db.makeSelectStatement(sql)
                        try test(SimpleRowConvertible.fetchOne(db, sql))
                        try test(SimpleRowConvertible.fetchOne(statement))
                        try test(SimpleRowConvertible.fetchOne(db, Request(statement: { statement }, adapter: nil)))
                    }
                    do {
                        let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName"
                        let statement = try db.makeSelectStatement(sql)
                        let adapter = SuffixRowAdapter(fromIndex: 1)
                        try test(SimpleRowConvertible.fetchOne(db, sql, adapter: adapter))
                        try test(SimpleRowConvertible.fetchOne(statement, adapter: adapter))
                        try test(SimpleRowConvertible.fetchOne(db, Request(statement: { statement }, adapter: adapter)))
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
                func test(_ value: @autoclosure () throws -> SimpleRowConvertible?, sql: String) throws {
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
                    try test(SimpleRowConvertible.fetchOne(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT 0, throw()"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
    
    func testFetchOneCompilationFailure() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                func test(_ value: @autoclosure () throws -> SimpleRowConvertible?, sql: String) throws {
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
                    try test(SimpleRowConvertible.fetchOne(db, sql), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db.makeSelectStatement(sql)), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: nil)), sql: sql)
                }
                do {
                    let sql = "SELECT * FROM nonExistingTable"
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(SimpleRowConvertible.fetchOne(db, sql, adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db.makeSelectStatement(sql), adapter: adapter), sql: sql)
                    try test(SimpleRowConvertible.fetchOne(db, Request(statement: { try db.makeSelectStatement(sql) }, adapter: adapter)), sql: sql)
                }
            }
        }
    }
}
