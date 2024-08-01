import XCTest
import GRDB

class DatabaseReaderTests : GRDBTestCase {
    func testAnyDatabaseReader() throws {
        // This test passes if this code compiles.
        let dbQueue = try DatabaseQueue()
        let _: any DatabaseReader = AnyDatabaseReader(dbQueue)
    }
    
    // Test passes if it compiles.
    func testInitFromGeneric(_ reader: some DatabaseReader) {
        _ = AnyDatabaseReader(reader)
    }
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testInitFromExistentialReader(_ reader: any DatabaseReader) {
        _ = AnyDatabaseReader(reader)
    }
    
    // Test passes if it compiles.
    // See <https://github.com/groue/GRDB.swift/issues/1541>
    func testInitFromExistentialWriter(_ writer: any DatabaseWriter) {
        _ = AnyDatabaseReader(writer)
    }
    
    // MARK: - Read
    
    func testReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: some DatabaseReader) throws {
            let count = try dbReader.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(setup(makeDatabasePool()).makeSnapshotPool())
#endif
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testAsyncAwait_ReadCanRead() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: some DatabaseReader) async throws {
            let count = try await dbReader.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
        try await test(setup(makeDatabasePool()).makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try await test(setup(makeDatabasePool()).makeSnapshotPool())
#endif
    }
    
    func testReadPreventsDatabaseModification() throws {
        func test(_ dbReader: some DatabaseReader) throws {
            do {
                try dbReader.read { db in
                    try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                }
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_READONLY {
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testAsyncAwait_ReadPreventsDatabaseModification() async throws {
        func test(_ dbReader: some DatabaseReader) async throws {
            do {
                try await dbReader.read { db in
                    try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                }
                XCTFail("Expected error")
            } catch DatabaseError.SQLITE_READONLY {
            }
        }
        
        try await test(makeDatabaseQueue())
        try await test(makeDatabasePool())
        try await test(makeDatabasePool().makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try await test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    // MARK: - UnsafeRead
    
    func testUnsafeReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: some DatabaseReader) throws {
            let count = try dbReader.unsafeRead { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(setup(makeDatabasePool()).makeSnapshotPool())
#endif
    }
    
    @available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
    func testAsyncAwait_UnsafeReadCanRead() async throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: some DatabaseReader) async throws {
            let count = try await dbReader.unsafeRead { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try await test(setup(makeDatabaseQueue()))
        try await test(setup(makeDatabasePool()))
        try await test(setup(makeDatabasePool()).makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try await test(setup(makeDatabasePool()).makeSnapshotPool())
#endif
    }
    
    // MARK: - UnsafeReentrantRead
    
    func testUnsafeReentrantReadCanRead() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ dbReader: some DatabaseReader) throws {
            let count = try dbReader.unsafeReentrantRead { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM t")
            }
            XCTAssertEqual(count, 0)
        }
        
        try test(setup(makeDatabaseQueue()))
        try test(setup(makeDatabasePool()))
        try test(setup(makeDatabasePool()).makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(setup(makeDatabasePool()).makeSnapshotPool())
#endif
    }
    
    func testUnsafeReentrantReadIsReentrant() throws {
        func test(_ dbReader: some DatabaseReader) throws {
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    func testUnsafeReentrantReadIsReentrantFromWrite() throws {
        func test(_ dbWriter: some DatabaseWriter) throws {
            try dbWriter.write { db1 in
                try dbWriter.unsafeReentrantRead { db2 in
                    try dbWriter.unsafeReentrantRead { db3 in
                        XCTAssertTrue(db1 === db2)
                        XCTAssertTrue(db2 === db3)
                    }
                }
            }
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
    }
    
    // MARK: - AsyncRead
    
    func testAsyncRead() throws {
        func test(_ dbReader: some DatabaseReader) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            var count: Int?
            dbReader.asyncRead { dbResult in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    count = try Int.fetchOne(dbResult.get(), sql: "SELECT COUNT(*) FROM sqlite_master")
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    func testAsyncReadPreventsDatabaseModification() throws {
        func test(_ dbReader: some DatabaseReader) throws {
            let expectation = self.expectation(description: "updates")
            let semaphore = DispatchSemaphore(value: 0)
            dbReader.asyncRead { dbResult in
                // Make sure this block executes asynchronously
                semaphore.wait()
                do {
                    try dbResult.get().execute(sql: "CREATE TABLE testAsyncReadPreventsDatabaseModification (a)")
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    // MARK: - Function
    
    func testAddFunction() throws {
        func test(_ dbReader: some DatabaseReader) throws {
            let value = try dbReader.read { db -> Int? in
                let f = DatabaseFunction("f", argumentCount: 0, pure: true) { _ in 0 }
                db.add(function: f)
                return try Int.fetchOne(db, sql: "SELECT f()")
            }
            XCTAssertEqual(value, 0)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    // MARK: - Collation
    
    func testAddCollation() throws {
        func test(_ dbReader: some DatabaseReader) throws {
            let value = try dbReader.read { db -> Int? in
                let collation = DatabaseCollation("c") { _, _ in .orderedSame }
                db.add(collation: collation)
                return try Int.fetchOne(db, sql: "SELECT 'foo' AS str ORDER BY str COLLATE c")
            }
            XCTAssertEqual(value, 0)
        }
        
        try test(makeDatabaseQueue())
        try test(makeDatabasePool())
        try test(makeDatabasePool().makeSnapshot())
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(makeDatabasePool().makeSnapshotPool())
#endif
    }
    
    // MARK: - Backup
    
    func testBackup() throws {
        func setup<T: DatabaseWriter>(_ dbWriter: T) throws -> T {
            try dbWriter.write { db in
                try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY)")
            }
            return dbWriter
        }
        func test(_ source: some DatabaseReader) throws {
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
#if SQLITE_ENABLE_SNAPSHOT || (!GRDBCUSTOMSQLITE && !GRDBCIPHER && (compiler(>=5.7.1) || !(os(macOS) || targetEnvironment(macCatalyst))))
        try test(setup(makeDatabasePool(configuration: Configuration())).makeSnapshotPool())
#endif
    }
}
