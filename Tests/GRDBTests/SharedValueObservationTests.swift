import XCTest
import GRDB

class SharedValueObservationTests: GRDBTestCase {
    func test_immediate_observationLifetime() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .immediate,
                extent: .observationLifetime)
        XCTAssertEqual(log.flush(), [])
        
        do {
            var value: Int?
            let cancellable = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value = $0 })
            
            XCTAssertEqual(value, 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
            
            cancellable.cancel()
            XCTAssertEqual(log.flush(), [])
        }
        
        do {
            var value: Int?
            let cancellable = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value = $0 })
            
            XCTAssertEqual(value, 0)
            XCTAssertEqual(log.flush(), [])
            
            cancellable.cancel()
            XCTAssertEqual(log.flush(), [])
        }

        sharedObservation = nil
        XCTAssertEqual(log.flush(), ["cancel"])
    }
    
    func test_immediate_observationLifetime_reentrancy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .immediate,
                extent: .observationLifetime)
        XCTAssertEqual(log.flush(), [])
        
        do {
            var value1: Int?
            var value2: Int?
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    value1 = value
                    _ = sharedObservation!.start(
                        onError: { XCTFail("Unexpected error \($0)") },
                        onChange: { value in
                            value2 = value
                        })
                })
            
            XCTAssertEqual(value1, 0)
            XCTAssertEqual(value2, 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
            
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), [])
        }
        
        sharedObservation = nil
        XCTAssertEqual(log.flush(), ["cancel"])
    }
    
    func test_immediate_whileObserved() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .immediate,
                extent: .whileObserved)
        XCTAssertEqual(log.flush(), [])
        
        do {
            var value: Int?
            let cancellable = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value = $0 })
            
            XCTAssertEqual(value, 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
            
            cancellable.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }
        
        do {
            var value: Int?
            let cancellable = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value = $0 })
            
            XCTAssertEqual(value, 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
            
            cancellable.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }

        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }
    
    func test_immediate_whileObserved_reentrancy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .immediate,
                extent: .whileObserved)
        XCTAssertEqual(log.flush(), [])
        
        do {
            var value1: Int?
            var value2: Int?
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    value1 = value
                    _ = sharedObservation!.start(
                        onError: { XCTFail("Unexpected error \($0)") },
                        onChange: { value in
                            value2 = value
                        })
                })
            
            XCTAssertEqual(value1, 0)
            XCTAssertEqual(value2, 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
            
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }
        
        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }

    func test_async_observationLifetime() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                extent: .observationLifetime)
        XCTAssertEqual(log.flush(), [])
        
        // --- Start observation 1
        var values1: [Int] = []
        let exp1 = expectation(description: "")
        exp1.expectedFulfillmentCount = 2
        exp1.assertForOverFulfill = false
        let cancellable1 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values1.append($0)
                exp1.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp1], timeout: 1)
        XCTAssertEqual(values1, [0, 1])
        XCTAssertEqual(log.flush(), [
            "start", "fetch", "value: 0", "tracked region: player(*)",
            "database did change", "fetch", "value: 1"])

        // --- Start observation 2
        var values2: [Int] = []
        let exp2 = expectation(description: "")
        exp2.expectedFulfillmentCount = 2
        exp2.assertForOverFulfill = false
        let cancellable2 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values2.append($0)
                exp2.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp2], timeout: 1)
        XCTAssertEqual(values1, [0, 1, 2])
        XCTAssertEqual(values2, [1, 2])
        XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])

        // --- Stop observation 1
        cancellable1.cancel()
        XCTAssertEqual(log.flush(), [])
        
        // --- Start observation 3
        var values3: [Int] = []
        let exp3 = expectation(description: "")
        exp3.expectedFulfillmentCount = 2
        exp3.assertForOverFulfill = false
        let cancellable3 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values3.append($0)
                exp3.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp3], timeout: 1)
        XCTAssertEqual(values1, [0, 1, 2])
        XCTAssertEqual(values2, [1, 2, 3])
        XCTAssertEqual(values3, [2, 3])
        XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
        
        // --- Stop observation 2
        cancellable2.cancel()
        XCTAssertEqual(log.flush(), [])
        
        // --- Stop observation 3
        cancellable3.cancel()
        XCTAssertEqual(log.flush(), [])
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), ["cancel"])
    }

    func test_async_observationLifetime_early_release() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                extent: .observationLifetime)
        XCTAssertEqual(log.flush(), [])
        
        // ---
        let exp = expectation(description: "")
        exp.expectedFulfillmentCount = 3
        let cancellable = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in
                // Early release
                sharedObservation = nil
                
                switch value {
                case 0:
                    XCTAssertEqual(log.flush(), ["start", "fetch", "value: 0", "tracked region: player(*)"])
                case 1:
                    XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 1"])
                case 2:
                    XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])
                default:
                    break
                }
                
                exp.fulfill()
                
                try! dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            })
        
        wait(for: [exp], timeout: 1)
        log.flush() // Ignore eventual notification of value: 3

        cancellable.cancel()
        XCTAssertEqual(log.flush(), ["cancel"])
    }

    func test_async_whileObserved() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var sharedObservation: SharedValueObservation<Int>? = ValueObservation
            .tracking(Table("player").fetchCount)
            .print(to: log)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: .main),
                extent: .whileObserved)
        XCTAssertEqual(log.flush(), [])
        
        // --- Start observation 1
        var values1: [Int] = []
        let exp1 = expectation(description: "")
        exp1.expectedFulfillmentCount = 2
        exp1.assertForOverFulfill = false
        let cancellable1 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values1.append($0)
                exp1.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp1], timeout: 1)
        XCTAssertEqual(values1, [0, 1])
        XCTAssertEqual(log.flush(), [
            "start", "fetch", "value: 0", "tracked region: player(*)",
            "database did change", "fetch", "value: 1"])

        // --- Start observation 2
        var values2: [Int] = []
        let exp2 = expectation(description: "")
        exp2.expectedFulfillmentCount = 2
        exp2.assertForOverFulfill = false
        let cancellable2 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values2.append($0)
                exp2.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp2], timeout: 1)
        XCTAssertEqual(values1, [0, 1, 2])
        XCTAssertEqual(values2, [1, 2])
        XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])

        // --- Stop observation 1
        cancellable1.cancel()
        XCTAssertEqual(log.flush(), [])
        
        // --- Start observation 3
        var values3: [Int] = []
        let exp3 = expectation(description: "")
        exp3.expectedFulfillmentCount = 2
        exp3.assertForOverFulfill = false
        let cancellable3 = sharedObservation!.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: {
                values3.append($0)
                exp3.fulfill()
            })
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
        wait(for: [exp3], timeout: 1)
        XCTAssertEqual(values1, [0, 1, 2])
        XCTAssertEqual(values2, [1, 2, 3])
        XCTAssertEqual(values3, [2, 3])
        XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
        
        // --- Stop observation 2
        cancellable2.cancel()
        XCTAssertEqual(log.flush(), [])
        
        // --- Stop observation 3
        cancellable3.cancel()
        XCTAssertEqual(log.flush(), ["cancel"])
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }
}

fileprivate class Log: TextOutputStream {
    var strings: [String] = []
    let lock = NSLock()
    
    func write(_ string: String) {
        lock.lock()
        strings.append(string)
        lock.unlock()
    }
    
    @discardableResult
    func flush() -> [String] {
        lock.lock()
        let result = strings
        strings = []
        lock.unlock()
        return result
    }
}
