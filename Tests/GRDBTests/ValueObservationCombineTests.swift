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

class ValueObservationCombineTests: GRDBTestCase {
    func testCombine2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("""
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [(Int, Int)] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        let observation1 = ValueObservation.trackingCount(T1.all())
        let observation2 = ValueObservation.trackingCount(T2.all())
        var observation = combine(observation1, observation2)
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { value in
            values.append(value)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t2")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("DELETE FROM t2")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(values.count, 4)
        XCTAssert(values[0] == (0, 0))
        XCTAssert(values[1] == (1, 0))
        XCTAssert(values[2] == (1, 1))
        XCTAssert(values[3] == (2, 2))
    }
    
    func testCombine3() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("""
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [(Int, Int, Int)] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        let observation1 = ValueObservation.trackingCount(T1.all())
        let observation2 = ValueObservation.trackingCount(T2.all())
        let observation3 = ValueObservation.trackingCount(T3.all())
        var observation = combine(observation1, observation2, observation3)
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { value in
            values.append(value)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t2")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t3")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("DELETE FROM t2")
            try db.execute("DELETE FROM t3")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(values.count, 5)
        XCTAssert(values[0] == (0, 0, 0))
        XCTAssert(values[1] == (1, 0, 0))
        XCTAssert(values[2] == (1, 1, 0))
        XCTAssert(values[3] == (1, 1, 1))
        XCTAssert(values[4] == (2, 2, 2))
    }
    
    func testCombine4() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("""
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [(Int, Int, Int, Int)] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 6
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        let observation1 = ValueObservation.trackingCount(T1.all())
        let observation2 = ValueObservation.trackingCount(T2.all())
        let observation3 = ValueObservation.trackingCount(T3.all())
        let observation4 = ValueObservation.trackingCount(T4.all())
        var observation = combine(observation1, observation2, observation3, observation4)
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { value in
            values.append(value)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t2")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t3")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t4")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("DELETE FROM t2")
            try db.execute("DELETE FROM t3")
            try db.execute("DELETE FROM t4")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(values.count, 6)
        XCTAssert(values[0] == (0, 0, 0, 0))
        XCTAssert(values[1] == (1, 0, 0, 0))
        XCTAssert(values[2] == (1, 1, 0, 0))
        XCTAssert(values[3] == (1, 1, 1, 0))
        XCTAssert(values[4] == (1, 1, 1, 1))
        XCTAssert(values[5] == (2, 2, 2, 2))
    }
    
    func testCombine5() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute("""
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t5(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [(Int, Int, Int, Int, Int)] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        struct T5: TableRecord { }
        let observation1 = ValueObservation.trackingCount(T1.all())
        let observation2 = ValueObservation.trackingCount(T2.all())
        let observation3 = ValueObservation.trackingCount(T3.all())
        let observation4 = ValueObservation.trackingCount(T4.all())
        let observation5 = ValueObservation.trackingCount(T5.all())
        var observation = combine(observation1, observation2, observation3, observation4, observation5)
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { value in
            values.append(value)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t5 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t2")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t3")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t4")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t5")
            try db.execute("INSERT INTO t5 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("DELETE FROM t1")
            try db.execute("DELETE FROM t2")
            try db.execute("DELETE FROM t3")
            try db.execute("DELETE FROM t4")
            try db.execute("DELETE FROM t5")
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
            try db.execute("INSERT INTO t5 DEFAULT VALUES")
        }
        try dbQueue.write { db in
            try db.execute("INSERT INTO t1 DEFAULT VALUES")
            try db.execute("INSERT INTO t2 DEFAULT VALUES")
            try db.execute("INSERT INTO t3 DEFAULT VALUES")
            try db.execute("INSERT INTO t4 DEFAULT VALUES")
            try db.execute("INSERT INTO t5 DEFAULT VALUES")
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(values.count, 7)
        XCTAssert(values[0] == (0, 0, 0, 0, 0))
        XCTAssert(values[1] == (1, 0, 0, 0, 0))
        XCTAssert(values[2] == (1, 1, 0, 0, 0))
        XCTAssert(values[3] == (1, 1, 1, 0, 0))
        XCTAssert(values[4] == (1, 1, 1, 1, 0))
        XCTAssert(values[5] == (1, 1, 1, 1, 1))
        XCTAssert(values[6] == (2, 2, 2, 2, 2))
    }
    
    func testHeterogeneusCombine2() throws {
        struct V1 { }
        struct V2 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation = combine(observation1, observation2)
        var value: (V1, V2)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine3() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation = combine(observation1, observation2, observation3)
        var value: (V1, V2, V3)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine4() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation = combine(observation1, observation2, observation3, observation4)
        var value: (V1, V2, V3, V4)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine5() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct V5 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation5 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V5() })
        let observation = combine(observation1, observation2, observation3, observation4, observation5)
        var value: (V1, V2, V3, V4, V5)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
}
