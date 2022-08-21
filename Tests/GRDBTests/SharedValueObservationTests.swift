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
        
        // We want to control when the shared observation is deallocated
        withExtendedLifetime(sharedObservation) { sharedObservation in
            do {
                var value: Int?
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value = $0 })
                
                XCTAssertEqual(value, 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
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
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
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
                var value: Int?
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value = $0 })
                
                XCTAssertEqual(value, 0)
                XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 0"])
                
                cancellable.cancel()
                XCTAssertEqual(log.flush(), ["cancel"])
            }
            
            do {
                var value: Int?
                let cancellable = sharedObservation!.start(
                    onError: { XCTFail("Unexpected error \($0)") },
                    onChange: { value = $0 })
                
                XCTAssertEqual(value, 0)
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
                "start", "fetch", "tracked region: player(*)", "value: 0",
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
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
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
                "start", "fetch", "tracked region: player(*)", "value: 0",
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
        }
        
        // --- Release shared observation
        sharedObservation = nil
        XCTAssertEqual(log.flush(), [])
    }
    
#if canImport(Combine)
    func test_error_recovery_observationLifetime() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var fetchError: Error? = nil
        let publisher = ValueObservation
            .tracking { db -> Int in
                if let error = fetchError { throw error }
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
            
            fetchError = TestError()
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
            fetchError = nil
            let recorder = publisher.record()
            if case .finished = try wait(for: recorder.completion, timeout: 1) { XCTFail("Expected error") }
            XCTAssertEqual(log.flush(), [])
        }
    }
#endif
    
#if canImport(Combine)
    func test_error_recovery_whileObserved() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
            }
        }
        
        let log = Log()
        var fetchError: Error? = nil
        let publisher = ValueObservation
            .tracking { db -> Int in
                if let error = fetchError { throw error }
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
            
            fetchError = TestError()
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
            fetchError = nil
            let recorder = publisher.record()
            try XCTAssertEqual(wait(for: recorder.next(), timeout: 1), 1)
            XCTAssertEqual(log.flush(), ["start", "fetch", "tracked region: player(*)", "value: 1"])
        }
    }
#endif
    
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func testAsyncAwait() async throws {
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
