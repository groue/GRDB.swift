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

class ValueObservationCompactMapTests: GRDBTestCase {
    func testCompactMap() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            // We need something to change
            try dbWriter.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [String] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 2
            
            // The base reducer
            var count = 0
            let reducer = AnyValueReducer(
                fetch: { _ in /* don't fetch anything */ },
                value: { _ -> Int? in
                    count += 1
                    return count
            })
            
            // Create an observation
            var observation = ValueObservation
                .tracking(DatabaseRegion.fullDatabase, reducer: { _ in reducer })
                .compactMap { count -> String? in
                    if count % 2 == 0 { return nil }
                    return "\(count)"
            }
            observation.extent = .databaseLifetime
            
            // Start observation
            _ = try observation.start(in: dbWriter) { count in
                counts.append(count)
                notificationExpectation.fulfill()
            }
            
            try dbWriter.writeWithoutTransaction { db in
                try db.execute("INSERT INTO t DEFAULT VALUES")
                try db.execute("INSERT INTO t DEFAULT VALUES")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(counts, ["1", "3"])
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
}
