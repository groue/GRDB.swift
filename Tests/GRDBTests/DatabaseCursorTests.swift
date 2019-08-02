import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
    func testStepError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = NSError(domain: "Custom", code: 0xDEAD)
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            let cursor = try Int.fetchCursor(db, sql: "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message, "\(customError)")
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT throw()`: \(customError)")
            }
        }
    }

    // TODO: this test should be duplicated for all cursor types
    func testStepDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        let customError = DatabaseError(resultCode: ResultCode(rawValue: 0xDEAD), message: "custom error")
        dbQueue.add(function: DatabaseFunction("throw", argumentCount: 0, pure: true) { _ in throw customError })
        try dbQueue.inDatabase { db in
            let cursor = try Int.fetchCursor(db, sql: "SELECT throw()")
            do {
                _ = try cursor.next()
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode.rawValue, 0xAD)
                XCTAssertEqual(error.extendedResultCode.rawValue, 0xDEAD)
                XCTAssertEqual(error.message, "custom error")
                XCTAssertEqual(error.sql!, "SELECT throw()")
                XCTAssertEqual(error.description, "SQLite error 173 with statement `SELECT throw()`: custom error")
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
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
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
    }
}
