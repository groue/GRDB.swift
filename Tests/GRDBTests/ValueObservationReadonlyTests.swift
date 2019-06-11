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

class ValueObservationReadonlyTests: GRDBTestCase {
    
    func testReadOnlyObservation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
            try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
        })
        let observer = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write {
                try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(counts, [0, 1])
        }
    }
    
    func testWriteObservationFailsByDefaultWithoutErrorHandling() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            return 0
        })
        
        do {
            _ = try observation.start(
                in: dbQueue,
                onChange: { _ in fatalError() })
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            XCTAssertEqual(error.message, "attempt to write a readonly database")
            XCTAssertEqual(error.sql!, "INSERT INTO t DEFAULT VALUES")
            XCTAssertEqual(error.description, "SQLite error 8 with statement `INSERT INTO t DEFAULT VALUES`: attempt to write a readonly database")
        }
    }

    func testWriteObservationFailsByDefaultWithErrorHandling() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            return 0
        })
        
        var error: DatabaseError!
        _ = observation.start(
            in: dbQueue,
            onError: { error = $0 as? DatabaseError },
            onChange: { _ in fatalError() })
        
        XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
        XCTAssertEqual(error.message, "attempt to write a readonly database")
        XCTAssertEqual(error.sql!, "INSERT INTO t DEFAULT VALUES")
        XCTAssertEqual(error.description, "SQLite error 8 with statement `INSERT INTO t DEFAULT VALUES`: attempt to write a readonly database")
    }
    
    func testWriteObservation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
            XCTAssert(db.isInsideTransaction, "expected a wrapping transaction")
            try db.execute(sql: "CREATE TEMPORARY TABLE temp AS SELECT * FROM t")
            let result = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM temp")!
            try db.execute(sql: "DROP TABLE temp")
            return result
        })
        observation.requiresWriteAccess = true
        let observer = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write {
                try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(counts, [0, 1])
        }
    }

    func testWriteObservationIsWrappedInSavepointWithoutErrorHandling() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        struct TestError: Error { }
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            throw TestError()
        })
        observation.requiresWriteAccess = true
        
        do {
            _ = try observation.start(
                in: dbQueue,
                onChange: { _ in fatalError() })
            XCTFail("Expected error")
        } catch is TestError {
        }
        
        let count = try dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
        XCTAssertEqual(count, 0)
    }

    func testWriteObservationIsWrappedInSavepointWithErrorHandling() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        }
        
        struct TestError: Error { }
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db in
            try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            throw TestError()
        })
        observation.requiresWriteAccess = true
        
        var error: Error?
        _ = observation.start(
            in: dbQueue,
            onError: { error = $0 },
            onChange: { _ in fatalError() })
        guard error is TestError else {
            XCTFail("Expected TestError")
            return
        }
        
        let count = try dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
        XCTAssertEqual(count, 0)
    }
}
