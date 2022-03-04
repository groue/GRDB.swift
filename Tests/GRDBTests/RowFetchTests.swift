import XCTest
import GRDB

class RowFetchTests: GRDBTestCase {

    func testFetchCursor() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: RowCursor) throws {
                // Check that RowCursor gives access to the raw SQLite API
                XCTAssertEqual(String(cString: sqlite3_column_name(cursor.statement.sqliteStatement, 0)), "firstName")
                
                var row = try cursor.next()!
                try XCTAssertEqual(row["firstName"] as String, "Arthur")
                try XCTAssertEqual(row["lastName"] as String, "Martin")
                row = try cursor.next()!
                try XCTAssertEqual(row["firstName"] as String, "Barbara")
                try XCTAssertEqual(row["lastName"] as String, "Gourde")
                XCTAssertTrue(try cursor.next() == nil) // end
                XCTAssertTrue(try cursor.next() == nil) // past the end
            }
            do {
                let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                try test(Row.fetchCursor(db, sql: sql))
                try test(Row.fetchCursor(statement))
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Row>(sql: sql).fetchCursor(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchCursor(db, sql: sql, adapter: adapter))
                try test(Row.fetchCursor(statement, adapter: adapter))
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchCursor(db))
            }
        }
    }
    
    func testFetchCursorWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Row> = "SELECT \("O'Brien")"
            let cursor = try request.fetchCursor(db)
            let row = try cursor.next()!
            try XCTAssertEqual(row[0], "O'Brien")
        }
    }
    
    func testFetchCursorStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            func test(_ cursor: RowCursor, sql: String) throws {
                do {
                    _ = try cursor.next()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `\(sql)`")
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
                try test(Row.fetchCursor(db, sql: sql), sql: sql)
                try test(Row.fetchCursor(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw(), NULL"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchCursor(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchCursor(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchCursor(db), sql: sql)
            }
        }
    }

    func testFetchCursorCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ cursor: @autoclosure () throws -> RowCursor, sql: String) throws {
                do {
                    _ = try cursor()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "no such table: nonExistingTable")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: no such table: nonExistingTable - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                try test(Row.fetchCursor(db, sql: sql), sql: sql)
                try test(Row.fetchCursor(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchCursor(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchCursor(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchCursor(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchCursor(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchCursor(db), sql: sql)
            }
        }
    }

    func testFetchAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ array: [Row]) {
                try XCTAssertEqual(array.map { try $0["firstName"] as String }, ["Arthur", "Barbara"])
                try XCTAssertEqual(array.map { try $0["lastName"] as String }, ["Martin", "Gourde"])
            }
            do {
                let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                try test(Row.fetchAll(db, sql: sql))
                try test(Row.fetchAll(statement))
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Row>(sql: sql).fetchAll(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchAll(db, sql: sql, adapter: adapter))
                try test(Row.fetchAll(statement, adapter: adapter))
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchAll(db))
            }
        }
    }
    
    func testFetchAllWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Row> = "SELECT \("O'Brien")"
            let rows = try request.fetchAll(db)
            try XCTAssertEqual(rows[0][0], "O'Brien")
        }
    }
    
    func testFetchAllStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            func test(_ array: @autoclosure () throws -> [Row], sql: String) throws {
                do {
                    _ = try array()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT throw()"
                try test(Row.fetchAll(db, sql: sql), sql: sql)
                try test(Row.fetchAll(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchAll(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }

    func testFetchAllCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ array: @autoclosure () throws -> [Row], sql: String) throws {
                do {
                    _ = try array()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "no such table: nonExistingTable")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: no such table: nonExistingTable - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                try test(Row.fetchAll(db, sql: sql), sql: sql)
                try test(Row.fetchAll(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchAll(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchAll(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchAll(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchAll(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchAll(db), sql: sql)
            }
        }
    }
    
    func testFetchSet() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ set: Set<Row>) {
                try XCTAssertEqual(Set(set.map { try $0["firstName"] as String }), ["Arthur", "Barbara"])
                try XCTAssertEqual(Set(set.map { try $0["lastName"] as String }), ["Martin", "Gourde"])
            }
            do {
                let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                try test(Row.fetchSet(db, sql: sql))
                try test(Row.fetchSet(statement))
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql)))
                try test(SQLRequest<Row>(sql: sql).fetchSet(db))
            }
            do {
                let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName UNION ALL SELECT 0, 'Barbara', 'Gourde'"
                let statement = try db.makeStatement(sql: sql)
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchSet(db, sql: sql, adapter: adapter))
                try test(Row.fetchSet(statement, adapter: adapter))
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchSet(db))
            }
        }
    }
    
    func testFetchSetWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Row> = "SELECT \("O'Brien")"
            let rows = try request.fetchSet(db)
            try XCTAssertEqual(rows.first![0], "O'Brien")
        }
    }
    
    func testFetchSetStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            func test(_ set: @autoclosure () throws -> Set<Row>, sql: String) throws {
                do {
                    _ = try set()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT throw()"
                try test(Row.fetchSet(db, sql: sql), sql: sql)
                try test(Row.fetchSet(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchSet(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchSet(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchSet(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchSet(db), sql: sql)
            }
        }
    }

    func testFetchSetCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ set: @autoclosure () throws -> Set<Row>, sql: String) throws {
                do {
                    _ = try set()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "no such table: nonExistingTable")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: no such table: nonExistingTable - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                try test(Row.fetchSet(db, sql: sql), sql: sql)
                try test(Row.fetchSet(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchSet(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchSet(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchSet(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchSet(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchSet(db), sql: sql)
            }
        }
    }

    func testFetchOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                func test(_ nilBecauseMissingRow: Row?) {
                    XCTAssertTrue(nilBecauseMissingRow == nil)
                }
                do {
                    let sql = "SELECT 1 WHERE 0"
                    let statement = try db.makeStatement(sql: sql)
                    try test(Row.fetchOne(db, sql: sql))
                    try test(Row.fetchOne(statement))
                    try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Row>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0, 1 WHERE 0"
                    let statement = try db.makeStatement(sql: sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchOne(db, sql: sql, adapter: adapter))
                    try test(Row.fetchOne(statement, adapter: adapter))
                    try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                    try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchOne(db))
                }
            }
            do {
                func test(_ row: Row?) {
                    try XCTAssertEqual(row!["firstName"] as String, "Arthur")
                    try XCTAssertEqual(row!["lastName"] as String, "Martin")
                }
                do {
                    let sql = "SELECT 'Arthur' AS firstName, 'Martin' AS lastName"
                    let statement = try db.makeStatement(sql: sql)
                    try test(Row.fetchOne(db, sql: sql))
                    try test(Row.fetchOne(statement))
                    try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql)))
                    try test(SQLRequest<Row>(sql: sql).fetchOne(db))
                }
                do {
                    let sql = "SELECT 0 AS firstName, 'Arthur' AS firstName, 'Martin' AS lastName"
                    let statement = try db.makeStatement(sql: sql)
                    let adapter = SuffixRowAdapter(fromIndex: 1)
                    try test(Row.fetchOne(db, sql: sql, adapter: adapter))
                    try test(Row.fetchOne(statement, adapter: adapter))
                    try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)))
                    try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchOne(db))
                }
            }
        }
    }
    
    func testFetchOneWithInterpolation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request: SQLRequest<Row> = "SELECT \("O'Brien")"
            let row = try request.fetchOne(db)
            try XCTAssertEqual(row![0], "O'Brien")
        }
    }
    
    func testFetchOneStepFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let customError = NSError(domain: "Custom", code: 0xDEAD)
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            func test(_ value: @autoclosure () throws -> Row?, sql: String) throws {
                do {
                    _ = try value()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "\(customError)")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT throw()"
                try test(Row.fetchOne(db, sql: sql), sql: sql)
                try test(Row.fetchOne(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT 0, throw()"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchOne(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchOne(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchOne(db), sql: sql)
            }
        }
    }

    func testFetchOneCompilationFailure() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func test(_ value: @autoclosure () throws -> Row?, sql: String) throws {
                do {
                    _ = try value()
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                    XCTAssertEqual(error.message, "no such table: nonExistingTable")
                    XCTAssertEqual(error.sql!, sql)
                    XCTAssertEqual(error.description, "SQLite error 1: no such table: nonExistingTable - while executing `\(sql)`")
                }
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                try test(Row.fetchOne(db, sql: sql), sql: sql)
                try test(Row.fetchOne(db.makeStatement(sql: sql)), sql: sql)
                try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql)), sql: sql)
                try test(SQLRequest<Row>(sql: sql).fetchOne(db), sql: sql)
            }
            do {
                let sql = "SELECT * FROM nonExistingTable"
                let adapter = SuffixRowAdapter(fromIndex: 1)
                try test(Row.fetchOne(db, sql: sql, adapter: adapter), sql: sql)
                try test(Row.fetchOne(db.makeStatement(sql: sql), adapter: adapter), sql: sql)
                try test(Row.fetchOne(db, SQLRequest<Void>(sql: sql, adapter: adapter)), sql: sql)
                try test(SQLRequest<Row>(sql: sql, adapter: adapter).fetchOne(db), sql: sql)
            }
        }
    }
}
