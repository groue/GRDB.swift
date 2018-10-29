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

class ValueObservationCountTests: GRDBTestCase {
    func testCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        struct T: TableRecord { }
        var observation = ValueObservation.forCount(T.all())
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { count in
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
    
    func testCountWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        struct T: TableRecord { }
        var observation = ValueObservation.forCount(withUniquing: T.all())
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { count in
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
