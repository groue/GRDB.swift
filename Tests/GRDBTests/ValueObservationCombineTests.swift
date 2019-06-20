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

class ValueObservationCombineTests: GRDBTestCase {
    func testCombine2() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2)
        let observer = try observation.start(in: dbQueue) { v0, v1 in
            values.append([v0, v1])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0],
                [1, 0],
                [1, 1],
                [2, 2]])
        }
    }
    
    func testCombine3() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2 in
            values.append([v0, v1, v2])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0],
                [1, 0, 0],
                [1, 1, 0],
                [1, 1, 1],
                [2, 2, 2]])
        }
    }
    
    func testCombine4() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 6
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation4 = T4.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2, v3 in
            values.append([v0, v1, v2, v3])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0, 0],
                [1, 0, 0, 0],
                [1, 1, 0, 0],
                [1, 1, 1, 0],
                [1, 1, 1, 1],
                [2, 2, 2, 2]])
        }
    }
    
    func testCombine5() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t5(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        struct T5: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation4 = T4.observationForCount()
        let observation5 = T5.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2, v3, v4 in
            values.append([v0, v1, v2, v3, v4])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0, 0, 0],
                [1, 0, 0, 0, 0],
                [1, 1, 0, 0, 0],
                [1, 1, 1, 0, 0],
                [1, 1, 1, 1, 0],
                [1, 1, 1, 1, 1],
                [2, 2, 2, 2, 2]])
        }
    }
    
    func testCombine6() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t5(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t6(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 8
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        struct T5: TableRecord { }
        struct T6: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation4 = T4.observationForCount()
        let observation5 = T5.observationForCount()
        let observation6 = T6.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2, v3, v4, v5 in
            values.append([v0, v1, v2, v3, v4, v5])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0, 0, 0, 0],
                [1, 0, 0, 0, 0, 0],
                [1, 1, 0, 0, 0, 0],
                [1, 1, 1, 0, 0, 0],
                [1, 1, 1, 1, 0, 0],
                [1, 1, 1, 1, 1, 0],
                [1, 1, 1, 1, 1, 1],
                [2, 2, 2, 2, 2, 2]])
        }
    }
    
    func testCombine7() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t5(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t6(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t7(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 9
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        struct T5: TableRecord { }
        struct T6: TableRecord { }
        struct T7: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation4 = T4.observationForCount()
        let observation5 = T5.observationForCount()
        let observation6 = T6.observationForCount()
        let observation7 = T7.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6, observation7)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2, v3, v4, v5, v6 in
            values.append([v0, v1, v2, v3, v4, v5, v6])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t7")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "DELETE FROM t7")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0, 0, 0, 0, 0],
                [1, 0, 0, 0, 0, 0, 0],
                [1, 1, 0, 0, 0, 0, 0],
                [1, 1, 1, 0, 0, 0, 0],
                [1, 1, 1, 1, 0, 0, 0],
                [1, 1, 1, 1, 1, 0, 0],
                [1, 1, 1, 1, 1, 1, 0],
                [1, 1, 1, 1, 1, 1, 1],
                [2, 2, 2, 2, 2, 2, 2]])
        }
    }
    
    func testCombine8() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t1(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t2(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t3(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t4(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t5(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t6(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t7(id INTEGER PRIMARY KEY AUTOINCREMENT);
                CREATE TABLE t8(id INTEGER PRIMARY KEY AUTOINCREMENT);
                """)
        }
        
        var values: [[Int]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 10
        
        struct T1: TableRecord { }
        struct T2: TableRecord { }
        struct T3: TableRecord { }
        struct T4: TableRecord { }
        struct T5: TableRecord { }
        struct T6: TableRecord { }
        struct T7: TableRecord { }
        struct T8: TableRecord { }
        let observation1 = T1.observationForCount()
        let observation2 = T2.observationForCount()
        let observation3 = T3.observationForCount()
        let observation4 = T4.observationForCount()
        let observation5 = T5.observationForCount()
        let observation6 = T6.observationForCount()
        let observation7 = T7.observationForCount()
        let observation8 = T8.observationForCount()
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6, observation7, observation8)
        let observer = try observation.start(in: dbQueue) { v0, v1, v2, v3, v4, v5, v6, v7 in
            values.append([v0, v1, v2, v3, v4, v5, v6, v7])
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t8 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t7")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t8")
                try db.execute(sql: "INSERT INTO t8 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "DELETE FROM t1")
                try db.execute(sql: "DELETE FROM t2")
                try db.execute(sql: "DELETE FROM t3")
                try db.execute(sql: "DELETE FROM t4")
                try db.execute(sql: "DELETE FROM t5")
                try db.execute(sql: "DELETE FROM t6")
                try db.execute(sql: "DELETE FROM t7")
                try db.execute(sql: "DELETE FROM t8")
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t8 DEFAULT VALUES")
            }
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO t1 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t2 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t3 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t4 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t5 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t6 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t7 DEFAULT VALUES")
                try db.execute(sql: "INSERT INTO t8 DEFAULT VALUES")
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(values, [
                [0, 0, 0, 0, 0, 0, 0, 0],
                [1, 0, 0, 0, 0, 0, 0, 0],
                [1, 1, 0, 0, 0, 0, 0, 0],
                [1, 1, 1, 0, 0, 0, 0, 0],
                [1, 1, 1, 1, 0, 0, 0, 0],
                [1, 1, 1, 1, 1, 0, 0, 0],
                [1, 1, 1, 1, 1, 1, 0, 0],
                [1, 1, 1, 1, 1, 1, 1, 0],
                [1, 1, 1, 1, 1, 1, 1, 1],
                [2, 2, 2, 2, 2, 2, 2, 2]])
        }
    }

    func testHeterogeneusCombine2() throws {
        struct V1 { }
        struct V2 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation = ValueObservation.combine(observation1, observation2)
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
        let observation = ValueObservation.combine(observation1, observation2, observation3)
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
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4)
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
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5)
        var value: (V1, V2, V3, V4, V5)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine6() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct V5 { }
        struct V6 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation5 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V5() })
        let observation6 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V6() })
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6)
        var value: (V1, V2, V3, V4, V5, V6)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine7() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct V5 { }
        struct V6 { }
        struct V7 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation5 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V5() })
        let observation6 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V6() })
        let observation7 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V7() })
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6, observation7)
        var value: (V1, V2, V3, V4, V5, V6, V7)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombine8() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct V5 { }
        struct V6 { }
        struct V7 { }
        struct V8 { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation5 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V5() })
        let observation6 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V6() })
        let observation7 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V7() })
        let observation8 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V8() })
        let observation = ValueObservation.combine(observation1, observation2, observation3, observation4, observation5, observation6, observation7, observation8)
        var value: (V1, V2, V3, V4, V5, V6, V7, V8)?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombined2() throws {
        struct V1 { }
        struct V2 { }
        struct Combined { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation = observation1.combine(observation2) { (v1: V1, v2: V2) -> Combined in Combined() }
        var value: Combined?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombined3() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct Combined { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation = observation1.combine(observation2, observation3) { (v1: V1, v2: V2, v3: V3) -> Combined in Combined() }
        var value: Combined?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombined4() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct Combined { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation = observation1.combine(observation2, observation3, observation4) { (v1: V1, v2: V2, v3: V3, v4: V4) -> Combined in Combined() }
        var value: Combined?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
    
    func testHeterogeneusCombined5() throws {
        struct V1 { }
        struct V2 { }
        struct V3 { }
        struct V4 { }
        struct V5 { }
        struct Combined { }
        let observation1 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V1() })
        let observation2 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V2() })
        let observation3 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V3() })
        let observation4 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V4() })
        let observation5 = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { _ in V5() })
        let observation = observation1.combine(observation2, observation3, observation4, observation5) { (v1: V1, v2: V2, v3: V3, v4: V4, v5: V5) -> Combined in Combined() }
        var value: Combined?
        _ = try observation.start(in: makeDatabaseQueue()) { value = $0 }
        XCTAssertNotNil(value)
    }
}
