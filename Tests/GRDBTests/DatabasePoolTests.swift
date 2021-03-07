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
}
