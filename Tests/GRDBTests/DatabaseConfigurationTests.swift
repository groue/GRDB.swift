import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class DatabaseConfigurationTests: GRDBTestCase {
    func testPrepareDatabase() throws {
        // prepareDatabase is called when connection opens
        var connectionCount = 0
        var configuration = Configuration()
        configuration.prepareDatabase = { db in
            connectionCount += 1
        }
        
        _ = DatabaseQueue(configuration: configuration)
        XCTAssertEqual(connectionCount, 1)
        
        _ = try makeDatabaseQueue(configuration: configuration)
        XCTAssertEqual(connectionCount, 2)
        
        let pool = try makeDatabasePool(configuration: configuration)
        XCTAssertEqual(connectionCount, 3)
        
        try pool.read { _ in }
        XCTAssertEqual(connectionCount, 4)
        
        try pool.makeSnapshot().read { _ in }
        XCTAssertEqual(connectionCount, 5)
    }
    
    func testPrepareDatabaseError() throws {
        struct TestError: Error { }
        var error: TestError?
        
        var configuration = Configuration()
        configuration.prepareDatabase = { db in
            if let error = error {
                throw error
            }
        }
        
        // TODO: what about in-memory DatabaseQueue???
        
        do {
            error = TestError()
            _ = try makeDatabaseQueue(configuration: configuration)
            XCTFail("Expected TestError")
        } catch is TestError { }
        
        do {
            error = TestError()
            _ = try makeDatabasePool(configuration: configuration)
            XCTFail("Expected TestError")
        } catch is TestError { }
        
        do {
            error = nil
            let pool = try makeDatabasePool(configuration: configuration)
            
            do {
                error = TestError()
                try pool.read { _ in }
                XCTFail("Expected TestError")
            } catch is TestError { }
            
            do {
                error = TestError()
                _ = try pool.makeSnapshot()
                XCTFail("Expected TestError")
            } catch is TestError { }
        }
    }
    
    func testAcceptsDoubleQuotedStringLiteralsDefault() throws {
        let configuration = Configuration()
        XCTAssertFalse(configuration.acceptsDoubleQuotedStringLiterals)
    }
    
    func testAcceptsDoubleQuotedStringLiteralsTrue() throws {
        var configuration = Configuration()
        configuration.acceptsDoubleQuotedStringLiterals = true
        let dbQueue = try makeDatabaseQueue(configuration: configuration)
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player(name TEXT);
                INSERT INTO player DEFAULT VALUES;
                """)
        }
        
        // Test SQLITE_DBCONFIG_DQS_DML
        let foo = try dbQueue.inDatabase { db in
            try String.fetchOne(db, sql: "SELECT \"foo\" FROM player")
        }
        XCTAssertEqual(foo, "foo")
        
        // Test SQLITE_DBCONFIG_DQS_DDL
        if sqlite3_libversion_number() > 3008010 {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE INDEX i ON player(\"foo\")")
            }
        }
    }
    
    func testAcceptsDoubleQuotedStringLiteralsFalse() throws {
        var configuration = Configuration()
        configuration.acceptsDoubleQuotedStringLiterals = false
        let dbQueue = try makeDatabaseQueue(configuration: configuration)
        try dbQueue.inDatabase { db in
            try db.execute(sql: """
                CREATE TABLE player(name TEXT);
                INSERT INTO player DEFAULT VALUES;
                """)
        }
        
        // Test SQLITE_DBCONFIG_DQS_DML
        do {
            let foo = try dbQueue.inDatabase { db in
                try String.fetchOne(db, sql: "SELECT \"foo\" FROM player")
            }
            if sqlite3_libversion_number() >= 3029000 {
                XCTFail("Expected error")
            } else {
                XCTAssertEqual(foo, "foo")
            }
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message, "no such column: foo")
            XCTAssertEqual(error.sql, "SELECT \"foo\" FROM player")
        }
        
        // Test SQLITE_DBCONFIG_DQS_DDL
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE INDEX i ON player(\"foo\")")
            }
            if sqlite3_libversion_number() >= 3029000 {
                XCTFail("Expected error")
            }
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssert([
                "no such column: foo",
                "table player has no column named foo"]
                .contains(error.message))
            XCTAssertEqual(error.sql, "CREATE INDEX i ON player(\"foo\")")
        }
    }
}
