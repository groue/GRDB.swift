import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationReadonlyTests: GRDBTestCase {
    
    func testReadOnlyObservation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
            try Int.fetchOne($0, "SELECT COUNT(*) FROM t")!
        })
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [0, 1])
    }
    
    func testWriteObservationFailsByDefault() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
            try db.execute("INSERT INTO t DEFAULT VALUES")
            return 0
        })

        do {
            _ = try observation.start(
                in: dbQueue,
                onError: { _ in fatalError() },
                onChange: { _ in fatalError() })
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            XCTAssertEqual(error.message, "attempt to write a readonly database")
            XCTAssertEqual(error.sql!, "INSERT INTO t DEFAULT VALUES")
            XCTAssertEqual(error.description, "SQLite error 8 with statement `INSERT INTO t DEFAULT VALUES`: attempt to write a readonly database")
        }
    }

    func testWriteObservation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
            XCTAssert(db.isInsideTransaction, "expected a wrapping transaction")
            try db.execute("CREATE TEMPORARY TABLE temp AS SELECT * FROM t")
            let result = try Int.fetchOne(db, "SELECT COUNT(*) FROM temp")!
            try db.execute("DROP TABLE temp")
            return result
        })
        observation.extent = .databaseLifetime
        observation.requiresWriteAccess = true
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [0, 1])
    }

    func testWriteObservationIsWrappedInSavepoint() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        struct TestError: Error { }
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db in
            try db.execute("INSERT INTO t DEFAULT VALUES")
            throw TestError()
        })
        observation.requiresWriteAccess = true

        do {
            _ = try observation.start(
                in: dbQueue,
                onError: { _ in fatalError() },
                onChange: { _ in fatalError() })
            XCTFail("Expected error")
        } catch is TestError {
        }
        
        let count = try dbQueue.read { try Int.fetchOne($0, "SELECT COUNT(*) FROM t")! }
        XCTAssertEqual(count, 0)
    }
}
