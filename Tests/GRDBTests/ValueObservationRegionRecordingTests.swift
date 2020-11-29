import XCTest
@testable import GRDB

class ValueObservationRegionRecordingTests: GRDBTestCase {
    func testRecordingSelectedRegion() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE team(id INTEGER PRIMARY KEY, name TEXT);
                CREATE TABLE player(id INTEGER PRIMARY KEY, name TEXT);
                """)
            
            do {
                var region = DatabaseRegion()
                db.recordingSelection(&region) { }
                XCTAssertTrue(region.isEmpty)
            }
            
            do {
                var region = DatabaseRegion.fullDatabase
                db.recordingSelection(&region) { }
                XCTAssertTrue(region.isFullDatabase)
            }
            
            do {
                var region = DatabaseRegion(table: "player")
                db.recordingSelection(&region) { }
                XCTAssertEqual(region.description, "player(*)")
            }
            
            do {
                var region = DatabaseRegion()
                _ = try db.recordingSelection(&region) {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                }
                XCTAssertEqual(region.description, "team(id,name)")
            }
            
            do {
                var region = DatabaseRegion.fullDatabase
                _ = try db.recordingSelection(&region) {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                }
                XCTAssertTrue(region.isFullDatabase)
            }
            
            do {
                var region = DatabaseRegion(table: "player")
                _ = try db.recordingSelection(&region) {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                }
                XCTAssertEqual(region.description, "player(*),team(id,name)")
            }
            
            do {
                var region = DatabaseRegion()
                _ = try db.recordingSelection(&region) {
                    _ = try Row.fetchAll(db, sql: "SELECT name FROM player")
                }
                XCTAssertEqual(region.description, "player(name)")
            }
            
            do {
                // Test for rowID optimization
                struct Player: TableRecord, FetchableRecord, Decodable { }
                var region = DatabaseRegion()
                _ = try db.recordingSelection(&region) {
                    _ = try Player.fetchOne(db, key: 123)
                }
                XCTAssert(region.description.contains("player(id,name)[123]"))
            }

            do {
                var region = DatabaseRegion()
                _ = try db.recordingSelection(&region) {
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
                var region5 = DatabaseRegion()
                _ = try db.recordingSelection(&region1) {
                    _ = try Row.fetchAll(db, sql: "SELECT * FROM team")
                    _ = try db.recordingSelection(&region2) {
                        db.recordingSelection(&region3) { }
                        _ = try Row.fetchAll(db, sql: "SELECT name FROM player")
                        db.recordingSelection(&region4) { }
                    }
                    _ = try db.recordingSelection(&region5) {
                        _ = try Row.fetchAll(db, sql: "SELECT * FROM player")
                    }
                }
                XCTAssertEqual(region1.description, "player(id,name),team(id,name)")
                XCTAssertEqual(region2.description, "player(name)")
                XCTAssertTrue(region3.isEmpty)
                XCTAssertTrue(region4.isEmpty)
                XCTAssertEqual(region5.description, "player(id,name)")
            }
        }
    }
    
    func testTupleObservation() throws {
        // Here we just test that user can destructure an observed tuple.
        // I'm completely paranoid about tuple destructuring - I can't wrap my
        // head about the rules that allow or disallow it.
        let dbQueue = try makeDatabaseQueue()
        let observation = ValueObservation.trackingConstantRegion { db -> (Int, String) in
            (0, "")
        }
        _ = observation.start(
            in: dbQueue,
            onError: { _ in },
            onChange: { (int: Int, string: String) in }) // <- destructure
    }
    
    func testVaryingRegionTrackingImmediateScheduling() throws {
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
        
        var regions: [DatabaseRegion] = []
        let observation = ValueObservation
            .tracking({ db -> Int in
                let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
                return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
            })
            .handleEvents(willTrackRegion: { regions.append($0) })
        
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                results.append(count)
                notificationExpectation.fulfill()
        })
        
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
            
            XCTAssertEqual(regions.map(\.description), [
                "a(value),source(name)",
                "b(value),source(name)"])
        }
    }
    
    func testVaryingRegionTrackingAsyncScheduling() throws {
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
        
        var regions: [DatabaseRegion] = []
        let observation = ValueObservation
            .tracking({ db -> Int in
                let table = try String.fetchOne(db, sql: "SELECT name FROM source")!
                return try Int.fetchOne(db, sql: "SELECT IFNULL(SUM(value), 0) FROM \(table)")!
            })
            .handleEvents(willTrackRegion: { regions.append($0) })
        
        let observer = observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                results.append(count)
                notificationExpectation.fulfill()
        })
        
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
            
            XCTAssertEqual(regions.map(\.description), [
                "a(value),source(name)",
                "b(value),source(name)"])
        }
    }
}
