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

class ValueObservationFetchTests: GRDBTestCase {
    func testRegionsAPI() {
        // single region
        _ = ValueObservation.tracking(DatabaseRegion(), fetch: { _ in })
        // variadic
        _ = ValueObservation.tracking(DatabaseRegion(), DatabaseRegion(), fetch: { _ in })
        // array
        _ = ValueObservation.tracking([DatabaseRegion()], fetch: { _ in })
    }
    
    func testFetch() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [Int] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 4
            
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            })
            let observer = observation.start(
                in: dbWriter,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    counts.append(count)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "UPDATE t SET id = id")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, [0, 1, 1, 2])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testFetchValue() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write {
                try $0.execute(sql: """
                    CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT);
                    INSERT INTO t DEFAULT VALUES;
                    """)
            }

            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            })
            
            let value = try dbWriter.read(observation.fetchValue)
            XCTAssertEqual(value, 1)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testFetchValueWithRequiredWriteAccess() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write {
                try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
            }

            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")!
            })
            observation.requiresWriteAccess = true
            
            do {
                _ = try dbWriter.read(observation.fetchValue)
                XCTFail("Expected error")
            } catch let dbError as DatabaseError where dbError.resultCode == .SQLITE_READONLY {
            }

            let value = try dbWriter.write(observation.fetchValue)
            XCTAssertEqual(value, 1)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    func testRemoveDuplicated() throws {
        func test(_ dbWriter: DatabaseWriter) throws {
            try dbWriter.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            var counts: [Int] = []
            let notificationExpectation = expectation(description: "notification")
            notificationExpectation.assertForOverFulfill = true
            notificationExpectation.expectedFulfillmentCount = 3
            
            let observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            }).removeDuplicates()
            let observer = observation.start(
                in: dbWriter,
                onError: { error in XCTFail("Unexpected error: \(error)") },
                onChange: { count in
                    counts.append(count)
                    notificationExpectation.fulfill()
            })
            try withExtendedLifetime(observer) {
                try dbWriter.writeWithoutTransaction { db in
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "UPDATE t SET id = id")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                }
                
                waitForExpectations(timeout: 1, handler: nil)
                XCTAssertEqual(counts, [0, 1, 2])
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
}
