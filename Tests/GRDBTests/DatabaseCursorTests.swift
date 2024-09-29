import XCTest
import GRDB

class DatabaseCursorTests: GRDBTestCase {
    
    // TODO: this test should be duplicated for all cursor types
    func testNextReturnsNilAfterExhaustion() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1 WHERE 0")
                XCTAssert(try cursor.next() == nil) // end
                XCTAssert(try cursor.next() == nil) // past the end
            }
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1")
                XCTAssertEqual(try cursor.next()!,  1)
                XCTAssert(try cursor.next() == nil) // end
                XCTAssert(try cursor.next() == nil) // past the end
            }
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1 UNION ALL SELECT 2")
                XCTAssertEqual(try cursor.next()!, 1)
                XCTAssertEqual(try cursor.next()!, 2)
                XCTAssert(try cursor.next() == nil) // end
                XCTAssert(try cursor.next() == nil) // past the end
            }
        }
    }

    // TODO: this test should be duplicated for all cursor types
    func testNextFollowedByForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1")
                XCTAssertEqual(try cursor.next()!,  1)
                try cursor.forEach { _ in
                    XCTFail("Cursor iteration should have ended")
                }
                XCTAssert(try cursor.next() == nil) // end
            }
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1 UNION SELECT 2")
                XCTAssertEqual(try cursor.next()!,  1)
                try cursor.forEach { i in
                    XCTAssertEqual(i,  2)
                }
                XCTAssert(try cursor.next() == nil) // end
            }
            do {
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1 UNION SELECT 2 UNION SELECT 3")
                XCTAssertEqual(try cursor.next()!,  1)
                try XCTAssertEqual(Array(cursor), [2, 3])
                XCTAssert(try cursor.next() == nil) // end
            }
            do {
                struct Break: Error { }
                let cursor = try Int.fetchCursor(db, sql: "SELECT 1 UNION SELECT 2 UNION SELECT 3")
                try? cursor.forEach { i in
                    XCTAssertEqual(i,  1)
                    throw Break()
                }
                try? cursor.forEach { i in
                    XCTAssertEqual(i,  2)
                    throw Break()
                }
                try? cursor.forEach { i in
                    XCTAssertEqual(i,  3)
                    throw Break()
                }
                XCTAssert(try cursor.next() == nil) // end
            }
        }
    }
    
    // TODO: this test should be duplicated for all cursor types
    func testStepError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        try dbQueue.inDatabase { db in
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            let cursor = try Int.fetchCursor(db, sql: "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "\(customError)")
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.description, "SQLite error 1: \(customError) - while executing `SELECT throw()`")
            }
        }
    }

    // TODO: this test should be duplicated for all cursor types
    func testStepDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = DatabaseError(resultCode: ResultCode(rawValue: 0xDEAD), message: "custom error")
        try dbQueue.inDatabase { db in
            db.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
            let cursor = try Int.fetchCursor(db, sql: "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 0xAD)
                XCTAssertEqual(error.extendedResultCode.rawValue, 0xDEAD)
                XCTAssertEqual(error.message, "custom error")
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.description, "SQLite error 173: custom error - while executing `SELECT throw()`")
            }
        }
    }
    
    // Regression test for http://github.com/groue/GRDB.swift/issues/583
    func testIssue583() throws {
        struct User: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
            static let databaseTableName: String = "user"
            
            var id: Int64?
            var username: String
            var isFlagged: Bool
            
            init(id: Int64? = nil, username: String, isFlagged: Bool = false) {
                self.id = id
                self.username = username
                self.isFlagged = isFlagged
            }
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        struct FlagUser: Codable, TableRecord, FetchableRecord, MutablePersistableRecord {
            static let databaseTableName: String = "flagUser"
            
            var username: String
        }
        
        let queue = try makeDatabaseQueue()
        try queue.write { database in
            try database.create(table: User.databaseTableName) { definition in
                definition.column("id", .integer).primaryKey(autoincrement: true)
                definition.column("username", .text).notNull()
                definition.column("isFlagged", .boolean).notNull().defaults(to: false)
            }
            
            try database.create(table: FlagUser.databaseTableName) { definition in
                definition.column("username", .text).notNull()
            }
            
            try [Int](0...50).forEach {
                var user = User(username: "User\($0)")
                try user.insert(database)
            }
            
            try [Int](40...60).forEach {
                var flag = FlagUser(username: "User\($0)")
                try flag.insert(database)
            }
        }
        
        let query = "SELECT * FROM flagUser WHERE (SELECT COUNT(id) FROM user WHERE username = flagUser.username AND isFlagged = 1) = 0"
        try queue.inDatabase { database in
            let cursor = try FlagUser.fetchCursor(database, sql: query)
            while let flagged = try cursor.next() {
                _ = try User.fetchOne(database, sql: "SELECT * FROM user WHERE username = '\(flagged.username)' LIMIT 1") ??
                    User(username: flagged.username)
            }
        }
        
        // For the record, the lines below show how this test used to fail,
        // with raw C SQLite3 apis. The faulty line is the call to
        // sqlite3_set_authorizer during the statement iteration.
        
//        var connection: SQLiteConnection? = nil
//        sqlite3_open_v2(":memory:", &connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)
//        sqlite3_extended_result_codes(connection, 1)
//
//        sqlite3_exec(connection, """
//             CREATE TABLE user (username TEXT NOT NULL);
//             CREATE TABLE flagUser (username TEXT NOT NULL);
//             INSERT INTO flagUser (username) VALUES ('User1');
//             INSERT INTO flagUser (username) VALUES ('User2');
//             """, nil, nil, nil)
//
//        var statement: SQLiteStatement? = nil
//        sqlite3_set_authorizer(connection, { (_, _, _, _, _, _) in SQLITE_OK }, nil)
//        sqlite3_prepare_v3(connection, """
//             SELECT * FROM flagUser WHERE (SELECT COUNT(*) FROM user WHERE username = flagUser.username) = 0
//             """, -1, 0, &statement, nil)
//        sqlite3_set_authorizer(connection, nil, nil)
//        while true {
//            let code = sqlite3_step(statement)
//            if code == SQLITE_DONE {
//                break
//            } else if code == SQLITE_ROW {
//                // part of the compilation of another statement, here
//                // reduced to the strict minimum that reproduces
//                // the error.
//                sqlite3_set_authorizer(connection, nil, nil)
//            } else {
//                print(String(cString: sqlite3_errmsg(connection)))
//                XCTFail("Error \(code)")
//                break
//            }
//        }
//        sqlite3_finalize(statement)
//        sqlite3_close_v2(connection)
    }
    
    // This test passes if it compiles
    func testAssociatedType() throws {
        func accept(_ cursor: some DatabaseCursor<String>) { }
        func useCursor(_ db: Database) throws {
            let cursor = try String.fetchCursor(db, sql: "SELECT 'foo'")
            accept(cursor)
        }
    }
    
    // For profiling tests
    let profilingSQL = """
        WITH RECURSIVE
          cnt(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM cnt WHERE x<10000000)
        SELECT x FROM cnt
        """
    
    // Profiling test
    func testRowCursorStep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: RowCursor = try Row.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testRowCursorForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: RowCursor = try Row.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
    
    // Profiling test
    func testDatabaseValueCursorStep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: DatabaseValueCursor<Int> = try Int.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testDatabaseValueCursorForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: DatabaseValueCursor<Int> = try Int.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
    
    // Profiling test
    func testNullableDatabaseValueCursorStep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: DatabaseValueCursor<Int?> = try Optional<Int>.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testNullableDatabaseValueCursorForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: DatabaseValueCursor<Int?> = try Optional<Int>.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
    
    // Profiling test
    func testFastDatabaseValueCursorStep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: FastDatabaseValueCursor<Int> = try Int.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testFastDatabaseValueCursorForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: FastDatabaseValueCursor<Int> = try Int.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
    
    // Profiling test
    func testFastNullableDatabaseValueCursorStep() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: FastDatabaseValueCursor<Int?> = try Optional<Int>.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testFastNullableDatabaseValueCursorForEach() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: FastDatabaseValueCursor<Int?> = try Optional<Int>.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
    
    // Profiling test
    func testRecordCursorStep() throws {
        struct S: FetchableRecord { init(row: Row) { } }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: RecordCursor<S> = try S.fetchCursor(db, sql: profilingSQL)
            while let _ = try cursor.next() { }
        }
    }
    
    // Profiling test
    func testRecordCursorForEach() throws {
        struct S: FetchableRecord { init(row: Row) { } }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let cursor: RecordCursor<S> = try S.fetchCursor(db, sql: profilingSQL)
            try cursor.forEach { _ in }
        }
    }
}
