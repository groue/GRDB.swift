import XCTest
import GRDB

class DatabaseRegionObservationTests: GRDBTestCase {
    func testDatabaseRegionObservation_FullDatabase() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
            try $0.execute(sql: "CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        let observation = DatabaseRegionObservation(tracking: .fullDatabase)
        
        var count = 0
        let cancellable = observation.start(
            in: dbQueue,
            onError: { XCTFail("Unexpected error: \($0)") },
            onChange: { db in
                count += 1
                notificationExpectation.fulfill()
            })
        
        try withExtendedLifetime(cancellable) {
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
    }

    func testDatabaseRegionObservation_ImmediateCancellation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.isInverted = true
        
        let observation = DatabaseRegionObservation(tracking: .fullDatabase)
        
        let cancellable = observation.start(
            in: dbQueue,
            onError: { XCTFail("Unexpected error: \($0)") },
            onChange: { db in
                notificationExpectation.fulfill()
            })
        cancellable.cancel()
        
        try withExtendedLifetime(cancellable) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
            }
            waitForExpectations(timeout: 0.1, handler: nil)
        }
    }
    
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
        
        let observation = DatabaseRegionObservation(tracking: request1, request2)
        
        var count = 0
        let cancellable = observation.start(
            in: dbQueue,
            onError: { XCTFail("Unexpected error: \($0)") },
            onChange: { db in
                count += 1
                notificationExpectation.fulfill()
            })
        
        try withExtendedLifetime(cancellable) {
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
        
        let observation = DatabaseRegionObservation(tracking: [request1, request2])
        
        var count = 0
        let cancellable = observation.start(
            in: dbQueue,
            onError: { XCTFail("Unexpected error: \($0)") },
            onChange: { db in
                count += 1
                notificationExpectation.fulfill()
            })
        
        try withExtendedLifetime(cancellable) {
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
    }
    
    func testDatabaseRegionDefaultCancellation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let observation = DatabaseRegionObservation(tracking: SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id"))
        
        var count = 0
        do {
            let cancellable = observation.start(
                in: dbQueue,
                onError: { XCTFail("Unexpected error: \($0)") },
                onChange: { db in
                    count += 1
                    notificationExpectation.fulfill()
                })
            
            try withExtendedLifetime(cancellable) {
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
        
        let observation = DatabaseRegionObservation(tracking: SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id"))
        
        var count = 0
        var cancellable: AnyDatabaseCancellable?
        cancellable = observation.start(
            in: dbQueue,
            onError: { XCTFail("Unexpected error: \($0)") },
            onChange: { db in
                cancellable?.cancel()
                count += 1
                notificationExpectation.fulfill()
            })
        
        try withExtendedLifetime(cancellable) {
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
    }

    func test_DatabaseRegionObservation_is_triggered_by_explicit_change_notification() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "test.sqlite")
        try dbQueue1.write { db in
            try db.execute(sql: "CREATE TABLE test(a)")
        }
        
        let undetectedExpectation = expectation(description: "undetected")
        undetectedExpectation.isInverted = true

        let detectedExpectation = expectation(description: "detected")
        
        let observation = DatabaseRegionObservation(tracking: Table("test"))
        let cancellable = observation.start(
            in: dbQueue1,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { _ in
                undetectedExpectation.fulfill()
                detectedExpectation.fulfill()
            })
        
        try withExtendedLifetime(cancellable) {
            // Change performed from external connection is not detected...
            let dbQueue2 = try makeDatabaseQueue(filename: "test.sqlite")
            try dbQueue2.write { db in
                try db.execute(sql: "INSERT INTO test (a) VALUES (1)")
            }
            wait(for: [undetectedExpectation], timeout: 2)
            
            // ... until we perform an explicit change notification
            try dbQueue1.write { db in
                try db.notifyChanges(in: Table("test"))
            }
            wait(for: [detectedExpectation], timeout: 2)
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/514
    // TODO: uncomment and make this test pass.
    // Well, actually, selecting only the rowid has SQLite authorizer advertise
    // that we select the whole table. This creates undesired database
    // observation notifications.
//    func testIssue514() throws {
//        let dbQueue = try makeDatabaseQueue()
//        try dbQueue.write { db in
//            try db.create(table: "gallery") { t in
//                t.primaryKey("id", .integer)
//                t.column("status", .integer)
//            }
//        }
//
//        struct Gallery: TableRecord { }
//        let observation = DatabaseRegionObservation(tracking: Gallery.select(Column("id")))
//
//        var notificationCount = 0
//        let cancellable = observation.start(
//            in: dbQueue,
//            onError: { XCTFail("Unexpected error: \($0)") },
//            onChange: { _ in
//                notificationCount += 1
//            })
//
//        try withExtendedLifetime(cancellable) {
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
