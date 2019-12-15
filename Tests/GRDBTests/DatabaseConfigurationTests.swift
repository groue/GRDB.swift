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
    // MARK: - prepareDatabase
    
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
    
    // MARK: - acceptsDoubleQuotedStringLiterals
    
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
    
    // MARK: - busyMode
    
    func testBusyModeImmediate() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
        // Work around SQLCipher bug when two connections are open to the
        // same empty database: make sure the database is not empty before
        // running this test
        try dbQueue1.inDatabase { db in
            try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
        }
        #endif
        
        var configuration2 = dbQueue1.configuration
        configuration2.busyMode = .immediateError
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite", configuration: configuration2)
        
        let s1 = DispatchSemaphore(value: 0)
        let s2 = DispatchSemaphore(value: 0)
        let queue = DispatchQueue.global(priority: .default)
        let group = DispatchGroup()
        
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.exclusive) { db in
                    s2.signal()
                    queue.asyncAfter(deadline: .now() + 1) {
                        s1.signal()
                    }
                    _ = s1.wait(timeout: .distantFuture)
                    return .commit
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        
        queue.async(group: group) {
            do {
                _ = s2.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.exclusive) { db in return .commit }
                XCTFail("Expected error")
            } catch let error as DatabaseError where error.resultCode == .SQLITE_BUSY {
            } catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
    }
    
    func testBusyModeTimeoutTooShort() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        #if GRDBCIPHER_USE_ENCRYPTION
        // Work around SQLCipher bug when two connections are open to the
        // same empty database: make sure the database is not empty before
        // running this test
        try dbQueue1.inDatabase { db in
            try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
        }
        #endif
        
        var configuration2 = dbQueue1.configuration
        configuration2.busyMode = .timeout(0.1)
        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite", configuration: configuration2)
        
        let s1 = DispatchSemaphore(value: 0)
        let s2 = DispatchSemaphore(value: 0)
        let queue = DispatchQueue.global(priority: .default)
        let group = DispatchGroup()
        
        queue.async(group: group) {
            do {
                try dbQueue1.inTransaction(.exclusive) { db in
                    s2.signal()
                    queue.asyncAfter(deadline: .now() + 1) {
                        s1.signal()
                    }
                    _ = s1.wait(timeout: .distantFuture)
                    return .commit
                }
            } catch {
                XCTFail("\(error)")
            }
        }
        
        queue.async(group: group) {
            do {
                _ = s2.wait(timeout: .distantFuture)
                try dbQueue2.inTransaction(.exclusive) { db in return .commit }
                XCTFail("Expected error")
            } catch let error as DatabaseError where error.resultCode == .SQLITE_BUSY {
            } catch {
                XCTFail("\(error)")
            }
        }
        
        _ = group.wait(timeout: .distantFuture)
    }
    
    // TODO: fix flaky test. It fails on Xcode 10.0, tvOS 10.0
//    func testBusyModeTimeoutTooLong() throws {
//        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
//        #if GRDBCIPHER_USE_ENCRYPTION
//        // Work around SQLCipher bug when two connections are open to the
//        // same empty database: make sure the database is not empty before
//        // running this test
//        try dbQueue1.inDatabase { db in
//            try db.execute(sql: "CREATE TABLE SQLCipherWorkAround (foo INTEGER)")
//        }
//        #endif
//        
//        var configuration2 = dbQueue1.configuration
//        configuration2.busyMode = .timeout(1)
//        let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite", configuration: configuration2)
//        
//        let s1 = DispatchSemaphore(value: 0)
//        let s2 = DispatchSemaphore(value: 0)
//        let queue = DispatchQueue.global(priority: .default)
//        let group = DispatchGroup()
//        
//        queue.async(group: group) {
//            do {
//                try dbQueue1.inTransaction(.exclusive) { db in
//                    s2.signal()
//                    queue.asyncAfter(deadline: .now() + 0.1) {
//                        s1.signal()
//                    }
//                    _ = s1.wait(timeout: .distantFuture)
//                    return .commit
//                }
//            } catch {
//                XCTFail("\(error)")
//            }
//        }
//        
//        queue.async(group: group) {
//            do {
//                _ = s2.wait(timeout: .distantFuture)
//                try dbQueue2.inTransaction(.exclusive) { db in return .commit }
//            } catch {
//                XCTFail("\(error)")
//            }
//        }
//        
//        _ = group.wait(timeout: .distantFuture)
//    }
}
