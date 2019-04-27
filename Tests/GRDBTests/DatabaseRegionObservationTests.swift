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

class DatabaseRegionObservationTests: GRDBTestCase {
    func testDatabaseRegionObservationVariadic() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
            try $0.execute(sql: "CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }

        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        let request1 = SQLRequest<Row>(sql: "SELECT * FROM t1 ORDER BY id")
        let request2 = SQLRequest<Row>(sql: "SELECT * FROM t2 ORDER BY id")
        
        var observation = DatabaseRegionObservation(tracking: request1, request2)
        observation.extent = .databaseLifetime

        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t1 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t2 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t1 (id, name) VALUES (2, 'foo')")
            try db.execute(sql: "INSERT INTO t2 (id, name) VALUES (2, 'foo')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 3)
    }
    
    func testDatabaseRegionObservationArray() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
            try $0.execute(sql: "CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        let request1 = SQLRequest<Row>(sql: "SELECT * FROM t1 ORDER BY id")
        let request2 = SQLRequest<Row>(sql: "SELECT * FROM t2 ORDER BY id")
        
        var observation = DatabaseRegionObservation(tracking: [request1, request2])
        observation.extent = .databaseLifetime
        
        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t1 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t2 (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t1 (id, name) VALUES (2, 'foo')")
            try db.execute(sql: "INSERT INTO t2 (id, name) VALUES (2, 'foo')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 3)
    }
    
    func testDatabaseRegionDefaultExtent() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let observation = DatabaseRegionObservation(tracking: SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id"))
        
        var count = 0
        do {
            let observer = try observation.start(in: dbQueue) { db in
                count += 1
                notificationExpectation.fulfill()
            }
            
            try withExtendedLifetime(observer) {
                try dbQueue.write { db in
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                }
                try dbQueue.write { db in
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                }
            }
        }
        // not notified
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 2)
    }
    
    func testDatabaseRegionExtentNextTransaction() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 1
        
        var observation = DatabaseRegionObservation(tracking: SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id"))
        observation.extent = .nextTransaction
        
        var count = 0
        _ = try observation.start(in: dbQueue) { db in
            count += 1
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        // not notified
        try dbQueue.write { db in
            try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertEqual(count, 1)
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/514
    // TODO: uncomment and make this test pass.
//    func testIssue514() throws {
//        let dbQueue = try makeDatabaseQueue()
//        try dbQueue.write { db in
//            try db.create(table: "gallery") { t in
//                t.column("id", .integer).primaryKey()
//                t.column("status", .integer)
//            }
//        }
//
//        struct Gallery: TableRecord { }
//        let observation = DatabaseRegionObservation(tracking: Gallery.select(Column("id")))
//
//        var notificationCount = 0
//        let observer = try observation.start(in: dbQueue) { _ in
//            notificationCount += 1
//        }
//
//        try withExtendedLifetime(observer) {
//            try dbQueue.write { db in
//                try db.execute(sql: "INSERT INTO gallery (id, status) VALUES (NULL, 0)")
//            }
//            XCTAssertEqual(notificationCount, 1)
//
//            try dbQueue.write { db in
//                try db.execute(sql: "UPDATE gallery SET status = 1")
//            }
//            XCTAssertEqual(notificationCount, 1) // status is not observed
//
//            try dbQueue.write { db in
//                try db.execute(sql: "DELETE FROM gallery")
//            }
//            XCTAssertEqual(notificationCount, 2)
//        }
//    }
}
