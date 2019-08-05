import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class ValueObservationRegionRecordingTests: GRDBTestCase {
    func testRecordingSelectedRegion() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE team(id INTEGER PRIMARY KEY, name TEXT);
                CREATE TABLE player(id INTEGER PRIMARY KEY, name TEXT);
                """)
            
            do {
                let (_, region) = db.recordingSelectedRegion { }
                XCTAssertTrue(region.isEmpty)
            }
            
            do {
                let (_, region) = try db.recordingSelectedRegion {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                }
                XCTAssertEqual(region.description, "team(id,name)")
            }
            
            do {
                let (_, region) = try db.recordingSelectedRegion {
                    _ = try Row.fetchAll(db, sql: "SELECT name FROM player")
                }
                XCTAssertEqual(region.description, "player(name)")
            }
            
            do {
                // Test for rowID optimization
                struct Player: TableRecord, FetchableRecord, Decodable { }
                let (_, region) = try db.recordingSelectedRegion {
                    _ = try Player.fetchOne(db, key: 123)
                }
                XCTAssertEqual(region.description, "player(id,name)[123]")
            }

            do {
                let (_, region) = try db.recordingSelectedRegion {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM player")
                }
                XCTAssertEqual(region.description, "player(id,name),team(id,name)")
            }

            do {
                var region1 = DatabaseRegion()
                var region2 = DatabaseRegion()
                var region3 = DatabaseRegion()
                var region4 = DatabaseRegion()
                (_, region1) = try db.recordingSelectedRegion {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                    (_, region2) = try db.recordingSelectedRegion {
                        _ = try Row.fetchAll(db, sql: "SELECT name FROM player")
                        (_, region3) = db.recordingSelectedRegion { }
                    }
                    (_, region4) = try db.recordingSelectedRegion {
                        _ = try Row.fetchAll(db, sql: "SELECT * FROM player")
                    }
                }
                XCTAssertEqual(region1.description, "player(id,name),team(id,name)")
                XCTAssertEqual(region2.description, "player(name)")
                XCTAssertTrue(region3.isEmpty)
                XCTAssertEqual(region4.description, "player(id,name)")
            }
        }
    }
    
    func testTupleObservation() throws {
        // Here we just test that user can destructure an observed tuple.
        // I'm completely paranoid about tuple destructuring - I can't wrap my
        // head about the rules that allow or disallow it.
        let dbQueue = try makeDatabaseQueue()
        let observation = ValueObservation.tracking { db -> (Int, String) in
            (0, "")
        }
        _ = observation.start(
            in: dbQueue,
            onError: { _ in },
            onChange: { (int: Int, string: String) in }) // <- destructure
    }
    
    func testMainQueueScheduling() throws {
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
            return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
        }
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
        XCTAssertEqual(token.observer.observedRegion.description, "a(value),source(name)")
        
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
            
            let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
            XCTAssertEqual(token.observer.observedRegion.description, "b(value),source(name)")
        }
    }
    
    func testAsyncSchedulingWithoutInitialFetch() throws {
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
            return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
        }
        observation.scheduling = .async(onQueue: DispatchQueue.main, startImmediately: false)
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        // Can't test observedRegion because it is defined asynchronously
        
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
            
            let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
            XCTAssertEqual(token.observer.observedRegion.description, "b(value),source(name)")
        }
    }
    
    func testAsyncSchedulingWithInitialFetch() throws {
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
        
        var observation = ValueObservation.tracking { db -> Int in
            let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
            return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
        }
        observation.scheduling = .async(onQueue: DispatchQueue.main, startImmediately: true)
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        // Can't test observedRegion because it is defined asynchronously
        
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
            
            let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
            XCTAssertEqual(token.observer.observedRegion.description, "b(value),source(name)")
        }
    }
    
    func testUnsafeSchedulingWithoutInitialFetch() throws {
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
            return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
        }
        observation.scheduling = .unsafe(startImmediately: false)
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        // Can't test observedRegion because it is defined asynchronously
        
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
            
            let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
            XCTAssertEqual(token.observer.observedRegion.description, "b(value),source(name)")
        }
    }
    
    func testUnsafeSchedulingWithInitialFetch() throws {
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
        
        var observation = ValueObservation.tracking { db -> Int in
            let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
            return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
        }
        observation.scheduling = .unsafe(startImmediately: true)
        
        let observer = try observation.start(in: dbQueue) { count in
            results.append(count)
            notificationExpectation.fulfill()
        }
        
        let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
        XCTAssertEqual(token.observer.observedRegion.description, "a(value),source(name)")
        
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
            
            let token = observer as! ValueObserverToken<ValueReducers.Fetch<Int>> // Non-public implementation detail
            XCTAssertEqual(token.observer.observedRegion.description, "b(value),source(name)")
        }
    }
}
