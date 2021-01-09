#if canImport(Combine)
import Combine
import GRDB
import XCTest

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
    var score: Int?
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text).notNull()
            t.column("score", .integer)
        }
    }
}

class DatabaseReaderReadPublisherTests : XCTestCase {
    
    // MARK: -
    
    func testReadPublisher() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Player.fetchCount(db)
            })
            let recorder = publisher.record()
            let value = try wait(for: recorder.single, timeout: 1)
            XCTAssertEqual(value, 0)
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    // TODO: fix crasher
    //
    // * thread #1, queue = 'com.apple.main-thread', stop reason = EXC_BAD_ACCESS (code=1, address=0x20)
    //     frame #0: 0x00007fff7115c6e8 libobjc.A.dylib`objc_retain + 24
    //     frame #1: 0x00007fff71c313a1 libswiftCore.dylib`swift::metadataimpl::ValueWitnesses<swift::metadataimpl::ObjCRetainableBox>::initializeWithCopy(swift::OpaqueValue*, swift::OpaqueValue*, swift::TargetMetadata<swift::InProcess> const*) + 17
    //     frame #2: 0x000000010d926309 GRDB`outlined init with copy of Subscribers.Completion<A.Publisher.Failure> at <compiler-generated>:0
    //     frame #3: 0x000000010d92474b GRDB`ReceiveValuesOnSubscription._receive(completion=failure, self=0x00000001064c13c0) at ReceiveValuesOn.swift:184:9
    //     frame #4: 0x000000010d92392c GRDB`closure #1 in closure #1 in closure #1 in ReceiveValuesOnSubscription.receive(self=0x00000001064c13c0, completion=failure) at ReceiveValuesOn.swift:158:26
    //     frame #5: 0x00007fff71d88f49 libswiftDispatch.dylib`reabstraction thunk helper from @escaping @callee_guaranteed () -> () to @escaping @callee_unowned @convention(block) () -> () + 25
    //     frame #6: 0x00007fff722b76c4 libdispatch.dylib`_dispatch_call_block_and_release + 12
    //     frame #7: 0x00007fff722b8658 libdispatch.dylib`_dispatch_client_callout + 8
    //     frame #8: 0x00007fff722c3cab libdispatch.dylib`_dispatch_main_queue_callback_4CF + 936
    //     frame #9: 0x00007fff38299e81 CoreFoundation`__CFRUNLOOP_IS_SERVICING_THE_MAIN_DISPATCH_QUEUE__ + 9
    //     frame #10: 0x00007fff38259c87 CoreFoundation`__CFRunLoopRun + 2028
    //     frame #11: 0x00007fff38258e3e CoreFoundation`CFRunLoopRunSpecific + 462
    //     frame #12: 0x00000001003aa82b XCTest`-[XCTWaiter waitForExpectations:timeout:enforceOrder:] + 823
    //     frame #13: 0x0000000100324a04 XCTest`-[XCTestCase(AsynchronousTesting) waitForExpectations:timeout:enforceOrder:] + 102
    //     frame #14: 0x000000010961363d GRDBOSXTests`XCTestCase.wait<R>(publisherExpectation=GRDBOSXTests.PublisherExpectations.Recording<Swift.Array<GRDB.Row>, Swift.Error> @ 0x00007ffeefbfd2f0, timeout=1, description="", self=0x0000000101d8a9c0) at PublisherExpectation.swift:97:9
    //     frame #15: 0x000000010915dbcf GRDBOSXTests`test #1 (reader=0x000000010672f210, self=0x0000000101d8a9c0) in DatabaseReaderReadPublisherTests.testReadPublisherError() at DatabaseReaderReadPublisherTests.swift:62:33
    //     frame #16: 0x000000010915dfc0 GRDBOSXTests`partial apply for test #1 (reader:) in DatabaseReaderReadPublisherTests.testReadPublisherError() at <compiler-generated>:0
    //     frame #17: 0x000000010915c334 GRDBOSXTests`thunk for @escaping @callee_guaranteed (@guaranteed DatabaseReader) -> (@error @owned Error) at <compiler-generated>:0
    //     frame #18: 0x000000010915e014 GRDBOSXTests`thunk for @escaping @callee_guaranteed (@guaranteed DatabaseReader) -> (@error @owned Error)partial apply at <compiler-generated>:0
    //     frame #19: 0x00000001095a85f8 GRDBOSXTests`closure #1 in Test.init(context=0x000000010672f210, _0=<unavailable>, test=0x000000010915e000 GRDBOSXTests`reabstraction thunk helper from @escaping @callee_guaranteed (@guaranteed GRDB.DatabaseReader) -> (@error @owned Swift.Error) to @escaping @callee_guaranteed (@in_guaranteed GRDB.DatabaseReader) -> (@error @owned Swift.Error)partial apply forwarder with unmangled suffix ".16" at <compiler-generated>) at Support.swift:13:41
    //     frame #20: 0x00000001095a86af GRDBOSXTests`partial apply for closure #1 in Test.init(repeatCount:_:) at <compiler-generated>:0
    //     frame #21: 0x00000001095a8a8f GRDBOSXTests`Test.run(context=0x000000010915e880 GRDBOSXTests`reabstraction thunk helper from @callee_guaranteed () -> (@owned GRDB.DatabaseReader, @error @owned Swift.Error) to @escaping @callee_guaranteed () -> (@out GRDB.DatabaseReader, @error @owned Swift.Error)partial apply forwarder with unmangled suffix ".17" at <compiler-generated>, self=(repeatCount = 1, test = 0x00000001095a8690 GRDBOSXTests`partial apply forwarder for closure #1 (A, Swift.Int) throws -> () in GRDBOSXTests.Test.init(repeatCount: Swift.Int, _: (A) throws -> ()) -> GRDBOSXTests.Test<A> at <compiler-generated>)) at Support.swift:24:17
    //   * frame #22: 0x000000010915d4ec GRDBOSXTests`DatabaseReaderReadPublisherTests.testReadPublisherError(self=0x0000000101d8a9c0) at DatabaseReaderReadPublisherTests.swift:71:14
    //     frame #23: 0x000000010915f26a GRDBOSXTests`@objc DatabaseReaderReadPublisherTests.testReadPublisherError() at <compiler-generated>:0
    //     frame #24: 0x00007fff3823c8ac CoreFoundation`__invoking___ + 140
    //     frame #25: 0x00007fff3823c751 CoreFoundation`-[NSInvocation invoke] + 303
    //     frame #26: 0x0000000100339d3a XCTest`__24-[XCTestCase invokeTest]_block_invoke_3 + 52
    //     frame #27: 0x0000000100402215 XCTest`+[XCTSwiftErrorObservation observeErrorsInBlock:] + 69
    //     frame #28: 0x0000000100339c3c XCTest`__24-[XCTestCase invokeTest]_block_invoke_2 + 119
    //     frame #29: 0x00000001003c959a XCTest`-[XCTMemoryChecker _assertInvalidObjectsDeallocatedAfterScope:] + 65
    //     frame #30: 0x00000001003448ea XCTest`-[XCTestCase assertInvalidObjectsDeallocatedAfterScope:] + 61
    //     frame #31: 0x0000000100339b82 XCTest`__24-[XCTestCase invokeTest]_block_invoke.231 + 199
    //     frame #32: 0x00000001003ae6d8 XCTest`-[XCTestCase(XCTIssueHandling) _caughtUnhandledDeveloperExceptionPermittingControlFlowInterruptions:caughtInterruptionException:whileExecutingBlock:] + 179
    //     frame #33: 0x0000000100339645 XCTest`-[XCTestCase invokeTest] + 1037
    //     frame #34: 0x000000010033b023 XCTest`__26-[XCTestCase performTest:]_block_invoke_2 + 43
    //     frame #35: 0x00000001003ae6d8 XCTest`-[XCTestCase(XCTIssueHandling) _caughtUnhandledDeveloperExceptionPermittingControlFlowInterruptions:caughtInterruptionException:whileExecutingBlock:] + 179
    //     frame #36: 0x000000010033af5a XCTest`__26-[XCTestCase performTest:]_block_invoke.362 + 86
    //     frame #37: 0x00000001003bfb9f XCTest`+[XCTContext runInContextForTestCase:markAsReportingBase:block:] + 220
    //     frame #38: 0x000000010033a7c7 XCTest`-[XCTestCase performTest:] + 695
    //     frame #39: 0x000000010038c6da XCTest`-[XCTest runTest] + 57
    //     frame #40: 0x0000000100334035 XCTest`__27-[XCTestSuite performTest:]_block_invoke + 329
    //     frame #41: 0x0000000100333856 XCTest`__59-[XCTestSuite _performProtectedSectionForTest:testSection:]_block_invoke + 24
    //     frame #42: 0x00000001003bfb9f XCTest`+[XCTContext runInContextForTestCase:markAsReportingBase:block:] + 220
    //     frame #43: 0x00000001003bfab0 XCTest`+[XCTContext runInContextForTestCase:block:] + 52
    //     frame #44: 0x000000010033380d XCTest`-[XCTestSuite _performProtectedSectionForTest:testSection:] + 148
    //     frame #45: 0x0000000100333b11 XCTest`-[XCTestSuite performTest:] + 290
    //     frame #46: 0x000000010038c6da XCTest`-[XCTest runTest] + 57
    //     frame #47: 0x0000000100334035 XCTest`__27-[XCTestSuite performTest:]_block_invoke + 329
    //     frame #48: 0x0000000100333856 XCTest`__59-[XCTestSuite _performProtectedSectionForTest:testSection:]_block_invoke + 24
    //     frame #49: 0x00000001003bfb9f XCTest`+[XCTContext runInContextForTestCase:markAsReportingBase:block:] + 220
    //     frame #50: 0x00000001003bfab0 XCTest`+[XCTContext runInContextForTestCase:block:] + 52
    //     frame #51: 0x000000010033380d XCTest`-[XCTestSuite _performProtectedSectionForTest:testSection:] + 148
    //     frame #52: 0x0000000100333b11 XCTest`-[XCTestSuite performTest:] + 290
    //     frame #53: 0x000000010038c6da XCTest`-[XCTest runTest] + 57
    //     frame #54: 0x0000000100334035 XCTest`__27-[XCTestSuite performTest:]_block_invoke + 329
    //     frame #55: 0x0000000100333856 XCTest`__59-[XCTestSuite _performProtectedSectionForTest:testSection:]_block_invoke + 24
    //     frame #56: 0x00000001003bfb9f XCTest`+[XCTContext runInContextForTestCase:markAsReportingBase:block:] + 220
    //     frame #57: 0x00000001003bfab0 XCTest`+[XCTContext runInContextForTestCase:block:] + 52
    //     frame #58: 0x000000010033380d XCTest`-[XCTestSuite _performProtectedSectionForTest:testSection:] + 148
    //     frame #59: 0x0000000100333b11 XCTest`-[XCTestSuite performTest:] + 290
    //     frame #60: 0x000000010038c6da XCTest`-[XCTest runTest] + 57
    //     frame #61: 0x00000001003dc8b5 XCTest`__44-[XCTTestRunSession runTestsAndReturnError:]_block_invoke_2 + 148
    //     frame #62: 0x00000001003bfb9f XCTest`+[XCTContext runInContextForTestCase:markAsReportingBase:block:] + 220
    //     frame #63: 0x00000001003bfab0 XCTest`+[XCTContext runInContextForTestCase:block:] + 52
    //     frame #64: 0x00000001003dc81a XCTest`__44-[XCTTestRunSession runTestsAndReturnError:]_block_invoke + 111
    //     frame #65: 0x00000001003dc99b XCTest`__44-[XCTTestRunSession runTestsAndReturnError:]_block_invoke.95 + 96
    //     frame #66: 0x000000010035acb8 XCTest`-[XCTestObservationCenter _observeTestExecutionForBlock:] + 325
    //     frame #67: 0x00000001003dc5e0 XCTest`-[XCTTestRunSession runTestsAndReturnError:] + 615
    //     frame #68: 0x0000000100317a7e XCTest`-[XCTestDriver _runTests] + 466
    //     frame #69: 0x00000001003bbb82 XCTest`_XCTestMain + 108
    //     frame #70: 0x0000000100002f07 xctest`main + 210
    //     frame #71: 0x00007fff72311cc9 libdyld.dylib`start + 1
    //     frame #72: 0x00007fff72311cc9 libdyld.dylib`start + 1
    func testReadPublisherError() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Row.fetchAll(db, sql: "THIS IS NOT SQL")
            })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.sql, "THIS IS NOT SQL")
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherIsAsynchronous() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) throws {
            let expectation = self.expectation(description: "")
            let semaphore = DispatchSemaphore(value: 0)
            let cancellable = reader
                .readPublisher(value: { db in
                    try Player.fetchCount(db)
                })
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in
                        semaphore.wait()
                        expectation.fulfill()
                })
            
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherDefaultScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) {
            let expectation = self.expectation(description: "")
            let cancellable = reader
                .readPublisher(value: { db in
                    try Player.fetchCount(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(.main))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(.main))
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherCustomScheduler() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func setUp<Writer: DatabaseWriter>(_ writer: Writer) throws -> Writer {
            try writer.write(Player.createTable)
            return writer
        }
        
        func test(reader: DatabaseReader) {
            let queue = DispatchQueue(label: "test")
            let expectation = self.expectation(description: "")
            let cancellable = reader
                .readPublisher(receiveOn: queue, value: { db in
                    try Player.fetchCount(db)
                })
                .sink(
                    receiveCompletion: { completion in
                        dispatchPrecondition(condition: .onQueue(queue))
                        expectation.fulfill()
                },
                    receiveValue: { _ in
                        dispatchPrecondition(condition: .onQueue(queue))
                })
            
            waitForExpectations(timeout: 1, handler: nil)
            cancellable.cancel()
        }
        
        try Test(test)
            .run { try setUp(DatabaseQueue()) }
            .runAtTemporaryDatabasePath { try setUp(DatabaseQueue(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)) }
            .runAtTemporaryDatabasePath { try setUp(DatabasePool(path: $0)).makeSnapshot() }
    }
    
    // MARK: -
    
    func testReadPublisherIsReadonly() throws {
        guard #available(OSX 10.15, iOS 13, tvOS 13, watchOS 6, *) else {
            throw XCTSkip("Combine is not available")
        }
        
        func test(reader: DatabaseReader) throws {
            let publisher = reader.readPublisher(value: { db in
                try Player.createTable(db)
            })
            let recorder = publisher.record()
            let recording = try wait(for: recorder.recording, timeout: 1)
            XCTAssertTrue(recording.output.isEmpty)
            assertFailure(recording.completion) { (error: DatabaseError) in
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
            }
        }
        
        try Test(test)
            .run { DatabaseQueue() }
            .runAtTemporaryDatabasePath { try DatabaseQueue(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0) }
            .runAtTemporaryDatabasePath { try DatabasePool(path: $0).makeSnapshot() }
    }
}
#endif
