import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseReaderTests : GRDBTestCase {
    
    func testReadPreventsDatabaseModification() throws {
        func test(_ dbReader: DatabaseReader) throws {
            do {
                try dbReader.read {
                    try $0.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError where error.resultCode == .SQLITE_READONLY {
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
        #if SQLITE_ENABLE_SNAPSHOT
        try test(makeDatabasePool().makeSharedSnapshot())
        #endif
    }

    func testUnsafeReentrantRead() throws {
        func test(_ dbReader: DatabaseReader) throws {
            try dbReader.unsafeReentrantRead { db1 in
                try dbReader.unsafeReentrantRead { db2 in
                    try dbReader.unsafeReentrantRead { db3 in
                        XCTAssertTrue(db1 === db2)
                        XCTAssertTrue(db2 === db3)
                    }
                }
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
        #if SQLITE_ENABLE_SNAPSHOT
        try test(makeDatabasePool().makeSharedSnapshot())
        #endif
    }
    
    func testAnyDatabaseReader() {
        // This test passes if this code compiles.
        let reader: DatabaseReader = DatabaseQueue()
        let _: DatabaseReader = AnyDatabaseReader(reader)
    }
    
    #if compiler(>=5.0)
    func testAsyncRead() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            var count: Int?
            dbReader.asyncRead { db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    count = try Int.fetchOne(db.get(), sql: "SELECT COUNT(*) FROM sqlite_master")
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
            semaphore.signal()
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertNotNil(count)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
        #if SQLITE_ENABLE_SNAPSHOT
        try test(makeDatabasePool().makeSharedSnapshot())
        #endif
    }
    #endif
    
    #if compiler(>=5.0)
    func testAsyncReadPreventsDatabaseModification() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbReader.asyncRead { db in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    try db.get().execute(sql: "CREATE TABLE testAsyncReadPreventsDatabaseModification (a)")
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
                expectation.fulfill()
            }
            semaphore.signal()
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
        #if SQLITE_ENABLE_SNAPSHOT
        try test(makeDatabasePool().makeSharedSnapshot())
        #endif
    }
    #endif
}
