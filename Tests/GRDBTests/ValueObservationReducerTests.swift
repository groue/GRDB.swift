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

class ValueObservationReducerTests: GRDBTestCase {
    func testReducer() throws {
        // We need something to change
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        // Track reducer proceess
        var fetchCount = 0
        var reduceCount = 0
        var errorCount = 0
        var changes: [String] = []
        let changeExpectation = expectation(description: "changes")
        changeExpectation.assertForOverFulfill = true
        changeExpectation.expectedFulfillmentCount = 3
        
        // A reducer which tracks its progress
        var dropNext = false // if true, reducer drops next value
        let reducer = AnyValueReducer(
            fetch: { db -> Int in
                fetchCount += 1
                return try Int.fetchOne(db, "SELECT COUNT(*) FROM t")!
            },
            value: { count -> String? in
                reduceCount += 1
                if dropNext {
                    dropNext = false
                    return nil
                }
                // just make sure the fetched type and the notified type can be different
                return count.description
            })
        
        // Create an observation
        let request = SQLRequest<Void>("SELECT * FROM t")
        let observation = ValueObservation.observing(request, reducer: reducer)

        // Start observation with default configuration
        let observer = try dbQueue.add(
            observation: observation,
            onError: { _ in errorCount += 1 },
            onChange: { change in
                changes.append(change)
                changeExpectation.fulfill()
        })
        
        // Default config stops when observer is deallocated: keep it alive for
        // the duration of the test:
        try withExtendedLifetime(observer) {
            
            // Test that default config synchronously notifies initial value
            XCTAssertEqual(fetchCount, 1)
            XCTAssertEqual(reduceCount, 1)
            XCTAssertEqual(errorCount, 0)
            XCTAssertEqual(changes, ["0"])
            
            try dbQueue.inDatabase { db in
                // A 1st notified transaction
                try db.inTransaction {
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    return .commit
                }
                
                // An untracked transaction
                try db.inTransaction {
                    try db.execute("CREATE TABLE ignored(a)")
                    return .commit
                }
                
                // A dropped transaction
                dropNext = true
                try db.inTransaction {
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    return .commit
                }
                
                // A rollbacked transaction
                try db.inTransaction {
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    return .rollback
                }

                // A 2nd notified transaction
                try db.inTransaction {
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    try db.execute("INSERT INTO t DEFAULT VALUES")
                    return .commit
                }
           }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(fetchCount, 4)
            XCTAssertEqual(reduceCount, 4)
            XCTAssertEqual(errorCount, 0)
            XCTAssertEqual(changes, ["0", "1", "5"])
        }
    }
    
    func testErrorThenSuccess() throws {
    }
    
    func testSuccessThenErrorThenSuccess() throws {
    }

}
