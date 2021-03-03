import XCTest
import Dispatch
import GRDB

class DatabaseQueueTests: GRDBTestCase {
    
    // Until SPM tests can load resources, disable this test for SPM.
    #if !SWIFT_PACKAGE
    func testInvalidFileFormat() throws {
        do {
            let testBundle = Bundle(for: type(of: self))
            let url = testBundle.url(forResource: "Betty", withExtension: "jpeg")!
            guard (try? Data(contentsOf: url)) != nil else {
                XCTFail("Missing file")
                return
            }
            _ = try DatabaseQueue(path: url.path)
            XCTFail("Expected error")
        } catch let error as DatabaseError {
            XCTAssertEqual(error.resultCode, .SQLITE_NOTADB)
            XCTAssert([
                "file is encrypted or is not a database",
                "file is not a database"].contains(error.message!))
        }
    }
    #endif
    
    func testAddRemoveFunction() throws {
        // Adding a function and then removing it should succeed
        let dbQueue = try makeDatabaseQueue()
        let fn = DatabaseFunction("succ", argumentCount: 1) { dbValues in
            guard let int = Int.fromDatabaseValue(dbValues[0]) else {
                return nil
            }
            return int + 1
        }
        try dbQueue.inDatabase { db in
            db.add(function: fn)
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT succ(1)"), 2) // 2
            db.remove(function: fn)
        }
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "SELECT succ(1)")
                XCTFail("Expected Error")
            }
            XCTFail("Expected Error")
        }
        catch let error as DatabaseError {
            // expected error
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message!.lowercased(), "no such function: succ") // lowercaseString: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "SELECT succ(1)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 1: no such function: succ - while executing `select succ(1)`")
        }
    }
    
    func testAddRemoveCollation() throws {
        // Adding a collation and then removing it should succeed
        let dbQueue = try makeDatabaseQueue()
        let collation = DatabaseCollation("test_collation_foo") { (string1, string2) in
            return (string1 as NSString).localizedStandardCompare(string2)
        }
        try dbQueue.inDatabase { db in
            db.add(collation: collation)
            try db.execute(sql: "CREATE TABLE files (name TEXT COLLATE TEST_COLLATION_FOO)")
            db.remove(collation: collation)
        }
        do {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
                XCTFail("Expected Error")
            }
            XCTFail("Expected Error")
        }
        catch let error as DatabaseError {
            // expected error
            XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
            XCTAssertEqual(error.message!.lowercased(), "no such collation sequence: test_collation_foo") // lowercaseString: accept multiple SQLite version
            XCTAssertEqual(error.sql!, "CREATE TABLE files_fail (name TEXT COLLATE TEST_COLLATION_FOO)")
            XCTAssertEqual(error.description.lowercased(), "sqlite error 1: no such collation sequence: test_collation_foo - while executing `create table files_fail (name text collate test_collation_foo)`")
        }
    }
    
    func testAllowsUnsafeTransactions() throws {
        dbConfiguration.allowsUnsafeTransactions = true
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.writeWithoutTransaction { db in
            try db.beginTransaction()
        }
        
        try dbQueue.writeWithoutTransaction { db in
            try db.commit()
        }
    }
    
    func testDefaultLabel() throws {
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(dbQueue.configuration.label, nil)
        dbQueue.inDatabase { db in
            XCTAssertEqual(db.configuration.label, nil)
            XCTAssertEqual(db.description, "GRDB.DatabaseQueue")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "GRDB.DatabaseQueue")
        }
    }
    
    func testCustomLabel() throws {
        dbConfiguration.label = "Toreador"
        let dbQueue = try makeDatabaseQueue()
        XCTAssertEqual(dbQueue.configuration.label, "Toreador")
        dbQueue.inDatabase { db in
            XCTAssertEqual(db.configuration.label, "Toreador")
            XCTAssertEqual(db.description, "Toreador")
            
            // This test CAN break in future releases: the dispatch queue labels
            // are documented to be a debug-only tool.
            let label = String(utf8String: __dispatch_queue_get_label(nil))
            XCTAssertEqual(label, "Toreador")
        }
    }
    
    func testTargetQueue() throws {
        guard #available(OSX 10.12, tvOS 10.0, *) else {
            throw XCTSkip("dispatchPrecondition(condition:) is not available")
        }
        
        func test(targetQueue: DispatchQueue) throws {
            dbConfiguration.targetQueue = targetQueue
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { _ in
                dispatchPrecondition(condition: .onQueue(targetQueue))
            }
            try dbQueue.read { _ in
                dispatchPrecondition(condition: .onQueue(targetQueue))
            }
        }
        
        // background queue
        try test(targetQueue: .global(qos: .background))
        
        // main queue
        let expectation = self.expectation(description: "main")
        DispatchQueue.global(qos: .default).async {
            try! test(targetQueue: .main)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testQoS() throws {
        guard #available(OSX 10.12, tvOS 10.0, *) else {
            throw XCTSkip("dispatchPrecondition(condition:) is not available")
        }
        
        func test(qos: DispatchQoS) throws {
            // https://forums.swift.org/t/what-is-the-default-target-queue-for-a-serial-queue/18094/5
            //
            // > [...] the default target queue [for a serial queue] is the
            // > [default] overcommit [global concurrent] queue.
            //
            // We want this default target queue in order to test database QoS
            // with dispatchPrecondition(condition:).
            //
            // > [...] You can get a reference to the overcommit queue by
            // > dropping down to the C function dispatch_get_global_queue
            // > (available in Swift with a __ prefix) and passing the private
            // > value of DISPATCH_QUEUE_OVERCOMMIT.
            // >
            // > [...] Of course you should not do this in production code,
            // > because DISPATCH_QUEUE_OVERCOMMIT is not a public API. I don't
            // > know of a way to get a reference to the overcommit queue using
            // > only public APIs.
            let DISPATCH_QUEUE_OVERCOMMIT: UInt = 2
            let targetQueue = __dispatch_get_global_queue(
                Int(qos.qosClass.rawValue.rawValue),
                DISPATCH_QUEUE_OVERCOMMIT)
            
            dbConfiguration.qos = qos
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { _ in
                dispatchPrecondition(condition: .onQueue(targetQueue))
            }
            try dbQueue.read { _ in
                dispatchPrecondition(condition: .onQueue(targetQueue))
            }
        }
        
        try test(qos: .background)
        try test(qos: .userInitiated)
    }
}
