import XCTest
import GRDB

class DatabasePoolTests: GRDBTestCase {
    func testDatabasePoolCreatesWalShm() throws {
        let dbPool = try makeDatabasePool()
        withExtendedLifetime(dbPool) {
            let fm = FileManager()
            XCTAssertTrue(fm.fileExists(atPath: dbPool.path + "-wal"))
            XCTAssertTrue(fm.fileExists(atPath: dbPool.path + "-shm"))
        }
    }
    
    func testPersistentWALModeEnabled() throws {
        let path: String
        do {
            dbConfiguration.prepareDatabase { db in
                var flag: CInt = 1
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool()
            path = dbPool.path
        }
        let fm = FileManager()
        XCTAssertTrue(fm.fileExists(atPath: path))
        XCTAssertTrue(fm.fileExists(atPath: path + "-wal"))
        XCTAssertTrue(fm.fileExists(atPath: path + "-shm"))
    }
    
    func testPersistentWALModeDisabled() throws {
        let path: String
        do {
            dbConfiguration.prepareDatabase { db in
                var flag: CInt = 0
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool()
            path = dbPool.path
        }
        let fm = FileManager()
        XCTAssertTrue(fm.fileExists(atPath: path))
        XCTAssertFalse(fm.fileExists(atPath: path + "-wal"))
        XCTAssertFalse(fm.fileExists(atPath: path + "-shm"))
    }
    
    // Regression test
    func testIssue931() throws {
        dbConfiguration.prepareDatabase { db in
            var flag: CInt = 0
            let code = withUnsafeMutablePointer(to: &flag) { flagP in
                sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
            }
            guard code == SQLITE_OK else {
                throw DatabaseError(resultCode: ResultCode(rawValue: code))
            }
        }
        let dbQueue = try makeDatabaseQueue()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1", migrate: { _ in })
        migrator.eraseDatabaseOnSchemaChange = true
        try migrator.migrate(dbQueue)
        
        // Trigger #931: the migrator creates a temporary database and
        // calls `sqlite3_file_control` as part of the preparation function.
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - Closing
    
    func testClose() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.close()
        
        // After close, access throws SQLITE_MISUSE
        do {
            try dbPool.write { db in
                try db.execute(sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        do {
            try dbPool.read { db in
                _ = try Row.fetchOne(db, sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        // After close, closing is a noop
        try dbPool.close()
    }
    
    func testCloseAfterUse() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            try db.execute(sql: "SELECT * FROM sqlite_master")
        }
        try dbPool.read { db in
            _ = try Row.fetchOne(db, sql: "SELECT * FROM sqlite_master")
        }
        try dbPool.close()
        
        // After close, access throws SQLITE_MISUSE
        do {
            try dbPool.write { db in
                try db.execute(sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        do {
            try dbPool.read { db in
                _ = try Row.fetchOne(db, sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        // After close, closing is a noop
        try dbPool.close()
    }
    
    func testCloseAfterCachedStatement() throws {
        let dbPool = try makeDatabasePool()
        try dbPool.write { db in
            _ = try db.cachedStatement(sql: "SELECT * FROM sqlite_master")
        }
        try dbPool.read { db in
            _ = try db.cachedStatement(sql: "SELECT * FROM sqlite_master")
        }
        try dbPool.close()
        
        // After close, access throws SQLITE_MISUSE
        do {
            try dbPool.write { db in
                try db.execute(sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        do {
            try dbPool.read { db in
                _ = try Row.fetchOne(db, sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        // After close, closing is a noop
        try dbPool.close()
    }
    
    func testCloseFailedDueToWriter() throws {
        let dbPool = try makeDatabasePool()
        let statement = try dbPool.write { db in
            try db.makeStatement(sql: "SELECT * FROM sqlite_master")
        }
        
        try withExtendedLifetime(statement) {
            do {
                try dbPool.close()
                XCTFail("Expected Error")
            } catch DatabaseError.SQLITE_BUSY { }
        }
        XCTAssert(lastMessage!.contains("unfinalized statement: SELECT * FROM sqlite_master"))
        
        // Database is not closed: no error
        try dbPool.write { db in
            try db.execute(sql: "SELECT * FROM sqlite_master")
        }
        try dbPool.read { db in
            try db.execute(sql: "SELECT * FROM sqlite_master")
        }
    }
    
    func testCloseFailedDueToReader() throws {
        let dbPool = try makeDatabasePool()
        let statement = try dbPool.read { db in
            try db.makeStatement(sql: "SELECT * FROM sqlite_master")
        }
        
        try withExtendedLifetime(statement) {
            do {
                try dbPool.close()
                XCTFail("Expected Error")
            } catch DatabaseError.SQLITE_BUSY { }
        }
        
        // The error message can be:
        // - unfinalized statement: SELECT * FROM sqlite_master
        // - close deferred due to unfinalized statement: "SELECT * FROM sqlite_master"
        //
        // The first comes from GRDB, and the second, depending on the SQLite
        // version, from `sqlite3_close_v2()`. Write the test so that it always pass:
        XCTAssert(lastMessage!.contains("unfinalized statement"))
        
        // Database is in a zombie state.
        // In the zombie state, access throws SQLITE_MISUSE
        do {
            try dbPool.write { db in
                try db.execute(sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        do {
            try dbPool.read { db in
                _ = try Row.fetchOne(db, sql: "SELECT * FROM sqlite_master")
            }
            XCTFail("Expected Error")
        } catch DatabaseError.SQLITE_MISUSE { }
        
        // In the zombie state, closing is a noop
        try dbPool.close()
    }
}
