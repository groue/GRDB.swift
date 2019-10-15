import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

class DatabaseReaderTests : GRDBTestCase {
    
    func testAnyDatabaseReader() {
        // This test passes if this code compiles.
        let reader: DatabaseReader = DatabaseQueue()
        let _: DatabaseReader = AnyDatabaseReader(reader)
    }
    
    // MARK: - Read
    
    func testReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: DatabaseReader) throws {
            let count = try dbReader.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
    }
    
    func testReadPreventsDatabaseModification() throws {
        func test(_ dbReader: DatabaseReader) throws {
            do {
                try dbReader.read { db in
                    try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                }
                XCTFail("Expected error")
            } catch let error as DatabaseError where error.resultCode == .SQLITE_READONLY {
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
    }
    
    // MARK: - UnsafeRead
    
    func testUnsafeReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: DatabaseReader) throws {
            let count = try dbReader.unsafeRead { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
    }
    
    // MARK: - UnsafeReentrantRead
    
    func testUnsafeReentrantReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: DatabaseReader) throws {
            let count = try dbReader.unsafeReentrantRead { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
    }
    
    func testUnsafeReentrantReadIsReentrant() throws {
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
    }
    
    // MARK: - AsyncRead
    
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
    }
    #endif
    
    // MARK: - Function
    
    func testAddFunction() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let f = DatabaseFunction("f", argumentCount: 0, pure: true) { _ in 0 }
            dbReader.add(function: f)
            let value = try dbReader.read { db in
                try Int.fetchOne(db, sql: "SELECT f()")
            }
            XCTAssertEqual(value, 0)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
    }
    
    // MARK: - Collation
    
    func testAddCollation() throws {
        func test(_ dbReader: DatabaseReader) throws {
            let collation = DatabaseCollation("c") { _, _ in .orderedSame }
            dbReader.add(collation: collation)
            let value = try dbReader.read { db in
                try Int.fetchOne(db, sql: "SELECT 'foo' AS str ORDER BY str COLLATE c")
            }
            XCTAssertEqual(value, 0)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
    }
    
    // MARK: - Backup
    
    func testBackup() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ source: DatabaseReader) throws {
            let dest = try makeDatabaseQueue(configuration: Configuration())
            try source.backup(to: dest)
            let count = try dest.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        // SQLCipher can't backup encrypted databases: use a pristine Configuration
        try test(setup(makeDatabaseQueue(configuration: Configuration())))
        try test(setup(makeDatabasePool(configuration: Configuration())))
        try test(setup(makeDatabasePool(configuration: Configuration())).makeSnapshot())
    }
}
