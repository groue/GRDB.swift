import XCTest
import GRDB

class SharedValueObservationTests: GRDBTestCase {
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testInitFromAnyDatabaseReader(reader: any DatabaseReader) {
        _ = ValueObservation
            .trackingConstantRegion { _ in }
            .shared(in: reader)
    }
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testInitFromAnyDatabaseWriter(writer: any DatabaseWriter) {
        _ = ValueObservation
            .trackingConstantRegion { _ in }
            .shared(in: writer)
    }
    
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
        
        // We want to control when the shared observation is deallocated
        withExtendedLifetime(sharedObservation) { sharedObservation in
            do {
                let valueMutex: Mutex<Int?> = Mutex(nil)
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in valueMutex.store(value) })
                
                XCTAssertEqual(valueMutex.load(), 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
                cancellable.cancel()
                XCTAssertEqual(log.flush(), [])
            }
            
            do {
                let valueMutex: Mutex<Int?> = Mutex(nil)
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in valueMutex.store(value) })
                
                XCTAssertEqual(valueMutex.load(), 0)
                XCTAssertEqual(log.flush(), [])
                
                cancellable.cancel()
                XCTAssertEqual(log.flush(), [])
            }
        }
        
        // Deallocate the shared observation
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
        
        // We want to control when the shared observation is deallocated
        withExtendedLifetime(sharedObservation) { sharedObservation in
            do {
                let value1Mutex: Mutex<Int?> = Mutex(nil)
                let value2Mutex: Mutex<Int?> = Mutex(nil)
                let cancellable1 = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in
                        value1Mutex.store(value)
                        _ = sharedObservation!.start(
                            onError: { XCTFail("Unexpected error \($0)") },
                            onChange: { value in
                                value2Mutex.store(value)
                            })
                    })
                
                XCTAssertEqual(value1Mutex.load(), 0)
                XCTAssertEqual(value2Mutex.load(), 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
                cancellable1.cancel()
                XCTAssertEqual(log.flush(), [])
            }
        }
        
        // Deallocate the shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), ["cancel"])
    }
    
#if canImport(Combine)
    func test_immediate_publisher() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let publisher = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(
                in: dbQueue,
                scheduling: .immediate)
            .publisher()
        
        do {
            let recorder = publisher.record()
            try XCTAssertEqual(recorder.next().get(), 0)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
        }
        
        do {
            let recorder = publisher.record()
            try XCTAssertEqual(recorder.next().get(), 1)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 2)
        }
    }
#endif
    
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
        
        // We want to control when the shared observation is deallocated
        withExtendedLifetime(sharedObservation) { sharedObservation in
            do {
                let valueMutex: Mutex<Int?> = Mutex(nil)
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in valueMutex.store(value) })
                
                XCTAssertEqual(valueMutex.load(), 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
                cancellable.cancel()
                XCTAssertEqual(log.flush(), ["cancel"])
            }
            
            do {
                let valueMutex: Mutex<Int?> = Mutex(nil)
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in valueMutex.store(value) })
                
                XCTAssertEqual(valueMutex.load(), 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
                cancellable.cancel()
                XCTAssertEqual(log.flush(), ["cancel"])
            }
        }
        
        // Deallocate the shared observation
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
        
        // We want to control when the shared observation is deallocated
        withExtendedLifetime(sharedObservation) { sharedObservation in
            let value1Mutex: Mutex<Int?> = Mutex(nil)
            let value2Mutex: Mutex<Int?> = Mutex(nil)
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    value1Mutex.store(value)
                    _ = sharedObservation!.start(
                        onError: { XCTFail("Unexpected error \($0)") },
                        onChange: { value in
                            value2Mutex.store(value)
                        })
                })
            
            XCTAssertEqual(value1Mutex.load(), 0)
            XCTAssertEqual(value2Mutex.load(), 0)
            XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
            
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }
        
        // Deallocate the shared observation
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
        
        // We want to control when the shared observation is deallocated
        try withExtendedLifetime(sharedObservation) { sharedObservation in
            // --- Start observation 1
            let values1Mutex: Mutex<[Int]> = Mutex([])
            let exp1 = expectation(description: "")
            exp1.expectedFulfillmentCount = 2
            exp1.assertForOverFulfill = false
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values1Mutex.withLock { $0.append(value) }
                    exp1.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp1], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1])
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "value: 1"])
            
            // --- Start observation 2
            let values2Mutex: Mutex<[Int]> = Mutex([])
            let exp2 = expectation(description: "")
            exp2.expectedFulfillmentCount = 2
            exp2.assertForOverFulfill = false
            let cancellable2 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values2Mutex.withLock { $0.append(value) }
                    exp2.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp2], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])
            
            // --- Stop observation 1
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Start observation 3
            let values3Mutex: Mutex<[Int]> = Mutex([])
            let exp3 = expectation(description: "")
            exp3.expectedFulfillmentCount = 2
            exp3.assertForOverFulfill = false
            let cancellable3 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values3Mutex.withLock { $0.append(value) }
                    exp3.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp3], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2, 3])
            XCTAssertEqual(values3Mutex.load(), [2, 3])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
            
            // --- Stop observation 2
            cancellable2.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Stop observation 3
            cancellable3.cancel()
            XCTAssertEqual(log.flush(), [])
        }
        
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
        nonisolated(unsafe) var sharedObservation: SharedValueObservation<Int>? = ValueObservation
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
                    XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
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
        
        cancellable.cancel()
        XCTAssertTrue(log.flush().contains("cancel")) // Ignore eventual notification of value: 3
    }
    
#if canImport(Combine)
    func test_async_publisher() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let publisher = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(in: dbQueue) // default async
            .publisher()
        
        do {
            let recorder = publisher.record()
            try XCTAssert(recorder.availableElements.get().isEmpty)
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 0)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
        }
        
        do {
            let recorder = publisher.record()
            try XCTAssert(recorder.availableElements.get().isEmpty)
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 2)
        }
    }
#endif
    
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
        
        // We want to control when the shared observation is deallocated
        try withExtendedLifetime(sharedObservation) { sharedObservation in
            // --- Start observation 1
            let values1Mutex: Mutex<[Int]> = Mutex([])
            let exp1 = expectation(description: "")
            exp1.expectedFulfillmentCount = 2
            exp1.assertForOverFulfill = false
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values1Mutex.withLock { $0.append(value) }
                    exp1.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp1], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1])
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "value: 1"])
            
            // --- Start observation 2
            let values2Mutex: Mutex<[Int]> = Mutex([])
            let exp2 = expectation(description: "")
            exp2.expectedFulfillmentCount = 2
            exp2.assertForOverFulfill = false
            let cancellable2 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values2Mutex.withLock { $0.append(value) }
                    exp2.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp2], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])
            
            // --- Stop observation 1
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Start observation 3
            let values3Mutex: Mutex<[Int]> = Mutex([])
            let exp3 = expectation(description: "")
            exp3.expectedFulfillmentCount = 2
            exp3.assertForOverFulfill = false
            let cancellable3 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values3Mutex.withLock { $0.append(value) }
                    exp3.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp3], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2, 3])
            XCTAssertEqual(values3Mutex.load(), [2, 3])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
            
            // --- Stop observation 2
            cancellable2.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Stop observation 3
            cancellable3.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }
    
    func test_task_observationLifetime() throws {
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
                scheduling: .task,
                extent: .observationLifetime)
        XCTAssertEqual(log.flush(), [])
        
        // We want to control when the shared observation is deallocated
        try withExtendedLifetime(sharedObservation) { sharedObservation in
            // --- Start observation 1
            let values1Mutex: Mutex<[Int]> = Mutex([])
            let exp1 = expectation(description: "")
            exp1.expectedFulfillmentCount = 2
            exp1.assertForOverFulfill = false
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values1Mutex.withLock { $0.append(value) }
                    exp1.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp1], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1])
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "value: 1"])
            
            // --- Start observation 2
            let values2Mutex: Mutex<[Int]> = Mutex([])
            let exp2 = expectation(description: "")
            exp2.expectedFulfillmentCount = 2
            exp2.assertForOverFulfill = false
            let cancellable2 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values2Mutex.withLock { $0.append(value) }
                    exp2.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp2], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])
            
            // --- Stop observation 1
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Start observation 3
            let values3Mutex: Mutex<[Int]> = Mutex([])
            let exp3 = expectation(description: "")
            exp3.expectedFulfillmentCount = 2
            exp3.assertForOverFulfill = false
            let cancellable3 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values3Mutex.withLock { $0.append(value) }
                    exp3.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp3], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2, 3])
            XCTAssertEqual(values3Mutex.load(), [2, 3])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
            
            // --- Stop observation 2
            cancellable2.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Stop observation 3
            cancellable3.cancel()
            XCTAssertEqual(log.flush(), [])
        }
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), ["cancel"])
    }
    
#if canImport(Combine)
    func test_task_publisher() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let publisher = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(in: dbQueue, scheduling: .task)
            .publisher()
        
        do {
            let recorder = publisher.record()
            try XCTAssert(recorder.availableElements.get().isEmpty)
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 0)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
        }
        
        do {
            let recorder = publisher.record()
            try XCTAssert(recorder.availableElements.get().isEmpty)
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 2)
        }
    }
#endif
    
    func test_task_whileObserved() throws {
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
                scheduling: .task,
                extent: .whileObserved)
        XCTAssertEqual(log.flush(), [])
        
        // We want to control when the shared observation is deallocated
        try withExtendedLifetime(sharedObservation) { sharedObservation in
            // --- Start observation 1
            let values1Mutex: Mutex<[Int]> = Mutex([])
            let exp1 = expectation(description: "")
            exp1.expectedFulfillmentCount = 2
            exp1.assertForOverFulfill = false
            let cancellable1 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values1Mutex.withLock { $0.append(value) }
                    exp1.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp1], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1])
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "value: 1"])
            
            // --- Start observation 2
            let values2Mutex: Mutex<[Int]> = Mutex([])
            let exp2 = expectation(description: "")
            exp2.expectedFulfillmentCount = 2
            exp2.assertForOverFulfill = false
            let cancellable2 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values2Mutex.withLock { $0.append(value) }
                    exp2.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp2], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 2"])
            
            // --- Stop observation 1
            cancellable1.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Start observation 3
            let values3Mutex: Mutex<[Int]> = Mutex([])
            let exp3 = expectation(description: "")
            exp3.expectedFulfillmentCount = 2
            exp3.assertForOverFulfill = false
            let cancellable3 = sharedObservation!.start(
                onError: { XCTFail("Unexpected error \($0)") },
                onChange: { value in
                    values3Mutex.withLock { $0.append(value) }
                    exp3.fulfill()
                })
            
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            wait(for: [exp3], timeout: 1)
            XCTAssertEqual(values1Mutex.load(), [0, 1, 2])
            XCTAssertEqual(values2Mutex.load(), [1, 2, 3])
            XCTAssertEqual(values3Mutex.load(), [2, 3])
            XCTAssertEqual(log.flush(), ["database did change", "fetch", "value: 3"])
            
            // --- Stop observation 2
            cancellable2.cancel()
            XCTAssertEqual(log.flush(), [])
            
            // --- Stop observation 3
            cancellable3.cancel()
            XCTAssertEqual(log.flush(), ["cancel"])
        }
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }

#if canImport(Combine)
    func test_error_recovery_observationLifetime() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        let fetchErrorMutex: Mutex<Error?> = Mutex(nil)
        let publisher = ValueObservation
            .tracking { db -> Int in
                try fetchErrorMutex.withLock { error in
                    if let error { throw error }
                }
                return try Table("player").fetchCount(db)
            }
            .print(to: log)
            .shared(in: dbQueue, extent: .observationLifetime)
            .publisher()
        
        do {
            let recorder1 = publisher.record()
            let recorder2 = publisher.record()
            
            try XCTAssertEqual(wait(for: recorder1.next(), timeout: 1), 0)
            try XCTAssertEqual(wait(for: recorder2.next(), timeout: 1), 0)
            
            fetchErrorMutex.store(TestError())
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            
            if case .finished = try wait(for: recorder1.completion, timeout: 1) { XCTFail("Expected error") }
            if case .finished = try wait(for: recorder2.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "failure: TestError()"])
        }
        
        do {
            let recorder = publisher.record()
            if case .finished = try wait(for: recorder.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), [])
        }
        
        do {
            fetchErrorMutex.store(nil)
            let recorder = publisher.record()
            if case .finished = try wait(for: recorder.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), [])
        }
    }
#endif
    
#if canImport(Combine)
    func test_error_recovery_whileObserved() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        let fetchErrorMutex: Mutex<Error?> = Mutex(nil)
        let publisher = ValueObservation
            .tracking { db -> Int in
                try fetchErrorMutex.withLock { error in
                    if let error { throw error }
                }
                return try Table("player").fetchCount(db)
            }
            .print(to: log)
            .shared(in: dbQueue, extent: .whileObserved)
            .publisher()
        
        do {
            let recorder1 = publisher.record()
            let recorder2 = publisher.record()
            
            try XCTAssertEqual(wait(for: recorder1.next(), timeout: 1), 0)
            try XCTAssertEqual(wait(for: recorder2.next(), timeout: 1), 0)
            
            fetchErrorMutex.store(TestError())
            try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES")}
            
            if case .finished = try wait(for: recorder1.completion, timeout: 1) { XCTFail("Expected error") }
            if case .finished = try wait(for: recorder2.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), [
                "start", "fetch", "tracked region: player(*)", "value: 0",
                "database did change", "fetch", "failure: TestError()"])
        }
        
        do {
            let recorder = publisher.record()
            if case .finished = try wait(for: recorder.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), ["start", "fetch", "failure: TestError()"])
        }
        
        do {
            fetchErrorMutex.store(nil)
            let recorder = publisher.record()
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
            XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 1"])
        }
    }
#endif
    
    func testAsyncAwait_mainQueue() async throws {
        let dbQueue = try makeDatabaseQueue()
        try await dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let values = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(in: dbQueue)
            .values()
        
        for try await value in values {
            XCTAssertEqual(value, 0)
            break
        }
    }
    
    func testAsyncAwait_task() async throws {
        let dbQueue = try makeDatabaseQueue()
        try await dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let values = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(in: dbQueue, scheduling: .task)
            .values()
        
        for try await value in values {
            XCTAssertEqual(value, 0)
            break
        }
    }

    // Regression test: a client can be cancelled from another thread while
    // the shared observation is notifying a fresh value.
    //
    // Notifying clients and cancelling clients must not happen under the
    // same lock. Otherwise, a notification that waits for a resource held by
    // the cancelling thread deadlocks. This happens in practice when a client
    // feeds an AsyncThrowingStream: `yield` waits for the consumer task's
    // status record lock, while `swift_task_cancel` holds that lock and runs
    // the stream's `onTermination` handler, which cancels the client.
    func test_cancellation_from_other_thread_during_value_notification() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }

        let sharedObservation = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: DispatchQueue(label: "SharedValueObservationTests")),
                extent: .observationLifetime)

        let cancellableMutex: Mutex<AnyDatabaseCancellable?> = Mutex(nil)
        let cancellationDidCompleteMutex: Mutex<Bool?> = Mutex(nil)
        let exp = expectation(description: "")
        let cancellable = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in
                guard value == 1 else { return }
                cancellationDidCompleteMutex.store(
                    Self.cancelFromOtherThreadAndWait(cancellableMutex.load()))
                exp.fulfill()
            })
        cancellableMutex.store(cancellable)

        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        wait(for: [exp], timeout: 5)
        XCTAssertEqual(cancellationDidCompleteMutex.load(), true)
    }

    // Regression test: a client can be cancelled from another thread while
    // the shared observation is notifying an error.
    //
    // See test_cancellation_from_other_thread_during_value_notification.
    func test_cancellation_from_other_thread_during_error_notification() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }

        let fetchErrorMutex: Mutex<Error?> = Mutex(nil)
        let sharedObservation = ValueObservation
            .tracking { db -> Int in
                try fetchErrorMutex.withLock { error in
                    if let error { throw error }
                }
                return try Table("player").fetchCount(db)
            }
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: DispatchQueue(label: "SharedValueObservationTests")),
                extent: .observationLifetime)

        let cancellableMutex: Mutex<AnyDatabaseCancellable?> = Mutex(nil)
        let cancellationDidCompleteMutex: Mutex<Bool?> = Mutex(nil)
        let initialValueExp = expectation(description: "initial value")
        let errorExp = expectation(description: "error")
        let cancellable = sharedObservation.start(
            onError: { _ in
                cancellationDidCompleteMutex.store(
                    Self.cancelFromOtherThreadAndWait(cancellableMutex.load()))
                errorExp.fulfill()
            },
            onChange: { _ in
                initialValueExp.fulfill()
            })
        cancellableMutex.store(cancellable)
        wait(for: [initialValueExp], timeout: 5)

        fetchErrorMutex.store(TestError())
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        wait(for: [errorExp], timeout: 5)
        XCTAssertEqual(cancellationDidCompleteMutex.load(), true)
    }

    // Regression test: a client cancelled from another thread is not
    // notified of a value that is being notified to other clients.
    func test_no_value_notification_after_cancellation_from_other_thread() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let queue = DispatchQueue(label: "SharedValueObservationTests")
        let sharedObservation = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: queue),
                extent: .observationLifetime)
        
        let initialValuesExp = expectation(description: "initial values")
        initialValuesExp.expectedFulfillmentCount = 2
        let notificationDidStartSemaphore = DispatchSemaphore(value: 0)
        let cancellationDidCompleteSemaphore = DispatchSemaphore(value: 0)
        
        // Client 1 blocks the notification of the second value until
        // client 2 is cancelled.
        let cancellable1 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in
                if value == 0 {
                    initialValuesExp.fulfill()
                } else {
                    notificationDidStartSemaphore.signal()
                    _ = cancellationDidCompleteSemaphore.wait(timeout: .now() + 5)
                }
            })
        
        let values2Mutex: Mutex<[Int]> = Mutex([])
        let cancellable2 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in
                values2Mutex.withLock { $0.append(value) }
                if value == 0 {
                    initialValuesExp.fulfill()
                }
            })
        wait(for: [initialValuesExp], timeout: 5)
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        XCTAssertEqual(notificationDidStartSemaphore.wait(timeout: .now() + 5), .success)
        cancellable2.cancel()
        cancellationDidCompleteSemaphore.signal()
        queue.sync { }
        
        XCTAssertEqual(values2Mutex.load(), [0])
        withExtendedLifetime(cancellable1) { }
    }
    
    // Regression test: a client cancelled from another thread is not
    // notified of an error that is being notified to other clients.
    func test_no_error_notification_after_cancellation_from_other_thread() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let fetchErrorMutex: Mutex<Error?> = Mutex(nil)
        let queue = DispatchQueue(label: "SharedValueObservationTests")
        let sharedObservation = ValueObservation
            .tracking { db -> Int in
                try fetchErrorMutex.withLock { error in
                    if let error { throw error }
                }
                return try Table("player").fetchCount(db)
            }
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: queue),
                extent: .observationLifetime)
        
        let initialValuesExp = expectation(description: "initial values")
        initialValuesExp.expectedFulfillmentCount = 2
        let notificationDidStartSemaphore = DispatchSemaphore(value: 0)
        let cancellationDidCompleteSemaphore = DispatchSemaphore(value: 0)
        
        // Client 1 blocks the notification of the error until
        // client 2 is cancelled.
        let cancellable1 = sharedObservation.start(
            onError: { _ in
                notificationDidStartSemaphore.signal()
                _ = cancellationDidCompleteSemaphore.wait(timeout: .now() + 5)
            },
            onChange: { _ in
                initialValuesExp.fulfill()
            })
        
        let error2Mutex: Mutex<Error?> = Mutex(nil)
        let cancellable2 = sharedObservation.start(
            onError: { error in
                error2Mutex.store(error)
            },
            onChange: { _ in
                initialValuesExp.fulfill()
            })
        wait(for: [initialValuesExp], timeout: 5)
        
        fetchErrorMutex.store(TestError())
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        XCTAssertEqual(notificationDidStartSemaphore.wait(timeout: .now() + 5), .success)
        cancellable2.cancel()
        cancellationDidCompleteSemaphore.signal()
        queue.sync { }
        
        XCTAssertNil(error2Mutex.load())
        withExtendedLifetime(cancellable1) { }
    }
    
    // Regression test: a client cancelled before the last value is
    // notified as its initial value is not notified.
    func test_no_initial_value_notification_after_cancellation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let queue = DispatchQueue(label: "SharedValueObservationTests")
        let sharedObservation = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(
                in: dbQueue,
                scheduling: .async(onQueue: queue),
                extent: .observationLifetime)
        
        let initialValueExp = expectation(description: "initial value")
        let cancellable1 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { _ in initialValueExp.fulfill() })
        wait(for: [initialValueExp], timeout: 5)
        
        // Block the queue until client 2 is cancelled.
        let cancellationDidCompleteSemaphore = DispatchSemaphore(value: 0)
        queue.async {
            _ = cancellationDidCompleteSemaphore.wait(timeout: .now() + 5)
        }
        
        let values2Mutex: Mutex<[Int]> = Mutex([])
        let cancellable2 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in
                values2Mutex.withLock { $0.append(value) }
            })
        cancellable2.cancel()
        cancellationDidCompleteSemaphore.signal()
        queue.sync { }
        
        XCTAssertEqual(values2Mutex.load(), [])
        withExtendedLifetime(cancellable1) { }
    }
    
    // Regression test: a shared observation that is restarted while the
    // failed upstream observation is starting keeps on observing
    // the database.
    func test_restart_during_failed_start_whileObserved() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        // The first fetch fails
        let fetchCountMutex = Mutex(0)
        let sharedObservation = ValueObservation
            .tracking { db -> Int in
                if fetchCountMutex.increment() == 1 {
                    throw TestError()
                }
                return try Table("player").fetchCount(db)
            }
            .shared(
                in: dbQueue,
                scheduling: .immediate,
                extent: .whileObserved)
        
        let cancellable2Mutex: Mutex<AnyDatabaseCancellable?> = Mutex(nil)
        let values2Mutex: Mutex<[Int]> = Mutex([])
        let value2Exp = expectation(description: "value")
        let cancellable1 = sharedObservation.start(
            onError: { _ in
                // Restart the shared observation from the immediate
                // error notification, before the failed upstream
                // observation has returned its cancellable.
                let cancellable2 = sharedObservation.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value in
                        values2Mutex.withLock { $0.append(value) }
                        if value == 1 {
                            value2Exp.fulfill()
                        }
                    })
                cancellable2Mutex.store(cancellable2)
            },
            onChange: { _ in XCTFail("Unexpected value") })
        XCTAssertEqual(values2Mutex.load(), [0])
        
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        wait(for: [value2Exp], timeout: 5)
        XCTAssertEqual(values2Mutex.load(), [0, 1])
        withExtendedLifetime(cancellable1) { }
        withExtendedLifetime(cancellable2Mutex) { }
    }
    
    // Regression test: the last value, notified as the initial value of a
    // new client, is not notified after a fresher value.
    func test_initial_value_is_not_notified_after_fresher_value() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let scheduler = ManualScheduler()
        let sharedObservation = ValueObservation
            .tracking(Table("player").fetchCount)
            .shared(
                in: dbQueue,
                scheduling: scheduler,
                extent: .observationLifetime)
        
        // Client 1 makes 0 the last value.
        let values1Mutex: Mutex<[Int]> = Mutex([])
        let cancellable1 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in values1Mutex.withLock { $0.append(value) } })
        XCTAssertTrue(scheduler.waitForScheduledActions(count: 1))
        scheduler.runScheduledActions()
        XCTAssertEqual(values1Mutex.load(), [0])
        
        // The fresh value 1 is scheduled, but not notified yet.
        try dbQueue.write { try $0.execute(sql: "INSERT INTO player DEFAULT VALUES") }
        XCTAssertTrue(scheduler.waitForScheduledActions(count: 1))
        
        // Client 2 starts. The last value 0 is scheduled as its initial
        // value, after the fresh value 1.
        let values2Mutex: Mutex<[Int]> = Mutex([])
        let cancellable2 = sharedObservation.start(
            onError: { XCTFail("Unexpected error \($0)") },
            onChange: { value in values2Mutex.withLock { $0.append(value) } })
        XCTAssertTrue(scheduler.waitForScheduledActions(count: 2))
        scheduler.runScheduledActions()
        
        XCTAssertEqual(values1Mutex.load(), [0, 1])
        XCTAssertEqual(values2Mutex.load(), [1])
        withExtendedLifetime((cancellable1, cancellable2)) { }
    }
    
    /// Cancels `cancellable` from another thread, and returns whether the
    /// cancellation completed before a timeout.
    ///
    /// Waiting for the other thread models a notification callback that
    /// waits for a resource held by a thread that is cancelling the client.
    /// A timeout reveals a deadlock, without hanging the test suite.
    private static func cancelFromOtherThreadAndWait(_ cancellable: AnyDatabaseCancellable?) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            cancellable?.cancel()
            semaphore.signal()
        }
        return semaphore.wait(timeout: .now() + 1) == .success
    }
}

private class Log: TextOutputStream {
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

private struct TestError: Error { }

/// A scheduler that runs scheduled actions on demand.
private final class ManualScheduler: ValueObservationScheduler, @unchecked Sendable {
    private let condition = NSCondition()
    private var actions: [@Sendable () -> Void] = [] // protected by condition
    
    func immediateInitialValue() -> Bool { false }
    
    func schedule(_ action: @escaping @Sendable () -> Void) {
        condition.lock()
        actions.append(action)
        condition.broadcast()
        condition.unlock()
    }
    
    /// Waits until `count` actions are scheduled, and returns whether
    /// they were scheduled before a timeout.
    func waitForScheduledActions(count: Int) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 5)
        condition.lock()
        defer { condition.unlock() }
        while actions.count < count {
            if !condition.wait(until: deadline) { return false }
        }
        return true
    }
    
    /// Runs scheduled actions, in order.
    func runScheduledActions() {
        condition.lock()
        let actions = self.actions
        self.actions = []
        condition.unlock()
        for action in actions {
            action()
        }
    }
}
