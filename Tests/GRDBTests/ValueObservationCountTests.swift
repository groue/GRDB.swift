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
        notificationExpectation.expectedFulfillmentCount = 5
        
        struct T: TableRecord { }
        var observation = ValueObservation.trackingCount(T.all())
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { count in
            counts.append(count)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t DEFAULT VALUES") // +1
            try db.execute("UPDATE t SET id = id")         // =
            try db.execute("INSERT INTO t DEFAULT VALUES") // +1
            try db.inTransaction {                         // +1
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("DELETE FROM t WHERE id = 1")
                return .commit
            }
            try db.execute("DELETE FROM t WHERE id = 2")   // -1
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(counts, [0, 1, 2, 3, 2])
    }
}
