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
        guard #available(iOS 13, macOS 10.15, tvOS 13, *) else {
            throw XCTSkip("Combine is not available")
        }
        
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
        guard #available(iOS 13, macOS 10.15, tvOS 13, *) else {
            throw XCTSkip("Combine is not available")
        }
        
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
        guard #available(iOS 13, macOS 10.15, tvOS 13, *) else {
            throw XCTSkip("Combine is not available")
        }
        
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
        guard #available(iOS 13, macOS 10.15, tvOS 13, *) else {
            throw XCTSkip("Combine is not available")
        }
        
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
        guard #available(iOS 13, macOS 10.15, tvOS 13, *) else {
            throw XCTSkip("Combine is not available")
        }
        
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
    
    @available(iOS 13, macOS 10.15, tvOS 13, *)
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
    
    @available(iOS 13, macOS 10.15, tvOS 13, *)
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
