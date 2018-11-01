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

class ValueObservationFetchTests: GRDBTestCase {
    func testFetch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
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
        try dbQueue.write {
            try $0.execute("UPDATE t SET id = id")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [0, 1, 1, 2])
    }
    
    func testFetchWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetchDistinct: {
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
        try dbQueue.write {
            try $0.execute("UPDATE t SET id = id")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t DEFAULT VALUES")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [0, 1, 2])
    }
}
