import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class ValueObservationRegionRecordingTests: GRDBTestCase {
    func testRegionRecording() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE source(name TEXT);
                INSERT INTO source VALUES ('a');
                CREATE TABLE a(value INTEGER);
                CREATE TABLE b(value INTEGER);
                """)
        }
        
        var results: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = ValueObservation.tracking { db -> Int in
            let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)")!
        }
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO a VALUES (1)") // 1
                try db.execute(sql: "INSERT INTO b VALUES (1)") // -
                try db.execute(sql: "INSERT INTO b VALUES (1)") // -
                try db.execute(sql: "UPDATE source SET name = 'b'") // 2
                try db.execute(sql: "INSERT INTO a VALUES (1)") // -
                try db.execute(sql: "INSERT INTO b VALUES (1)") // 3
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [0, 1, 2, 3])
        }
    }
    
    func testRegionRecordingWithoutInitialFetch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE source(name TEXT);
                INSERT INTO source VALUES ('a');
                CREATE TABLE a(value INTEGER);
                CREATE TABLE b(value INTEGER);
                """)
        }
        
        var results: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.tracking { db -> Int in
            let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
            return try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)")!
        }
        observation.scheduling = .async(onQueue: DispatchQueue.main, startImmediately: false)
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO a VALUES (1)") // 1
                try db.execute(sql: "INSERT INTO b VALUES (1)") // -
                try db.execute(sql: "INSERT INTO b VALUES (1)") // -
                try db.execute(sql: "UPDATE source SET name = 'b'") // 2
                try db.execute(sql: "INSERT INTO a VALUES (1)") // -
                try db.execute(sql: "INSERT INTO b VALUES (1)") // 3
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [1, 2, 3])
        }
    }
}
