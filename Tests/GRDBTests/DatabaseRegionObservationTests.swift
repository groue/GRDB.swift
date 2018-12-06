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

class DatabaseRegionObservationTests: GRDBTestCase {
    func testDatabaseRegionObservation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let request = SQLRequest<Row>("SELECT * FROM t ORDER BY id")
        let observation = DatabaseRegionObservation(tracking: { db in
            try request.databaseRegion(db)
        })
        let observer = try observation.start(in: dbQueue) { db in
            let rows = try! request.fetchAll(db)
            results.append(rows)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute("UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute("DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute("DELETE FROM t WHERE id = 1")                 // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        XCTAssertEqual(results, [
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
            [["id":2, "name":"bar"]]])
    }
    
    func testDatabaseRegionObservationVariadic() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
            try $0.execute("CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }

        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        let request1 = SQLRequest<Row>("SELECT * FROM t1 ORDER BY id")
        let request2 = SQLRequest<Row>("SELECT * FROM t2 ORDER BY id")
        
        var observation = DatabaseRegionObservation(tracking: request1, request2)
        observation.extent = .databaseLifetime

        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 (id, name) VALUES (2, 'foo')")
            try db.execute("INSERT INTO t2 (id, name) VALUES (2, 'foo')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 3)
    }
    
    func testDatabaseRegionObservationArray() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
            try $0.execute("CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        let request1 = SQLRequest<Row>("SELECT * FROM t1 ORDER BY id")
        let request2 = SQLRequest<Row>("SELECT * FROM t2 ORDER BY id")
        
        var observation = DatabaseRegionObservation(tracking: [request1, request2])
        observation.extent = .databaseLifetime
        
        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 (id, name) VALUES (2, 'foo')")
            try db.execute("INSERT INTO t2 (id, name) VALUES (2, 'foo')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 3)
    }
    
    func testDatabaseRegionDefaultExtent() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let observation = DatabaseRegionObservation(tracking: SQLRequest<Row>("SELECT * FROM t ORDER BY id"))
        
        var count = 0
        do {
            let observer = try observation.start(in: dbQueue) { db in
                count += 1
                notificationExpectation.fulfill()
            }
            
            try withExtendedLifetime(observer) {
                try dbQueue.write { db in
                    try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
                }
                try dbQueue.write { db in
                    try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
                }
            }
        }
        // not notified
        try dbQueue.write { db in
            try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 2)
    }
    
    func testDatabaseRegionExtentNextTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 1
        
        var observation = DatabaseRegionObservation(tracking: SQLRequest<Row>("SELECT * FROM t ORDER BY id"))
        observation.extent = .nextTransaction
        
        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        // not notified
        try dbQueue.write { db in
            try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 1)
    }
}
