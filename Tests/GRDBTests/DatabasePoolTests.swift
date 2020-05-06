import XCTest
import GRDB

class DatabasePoolTests: GRDBTestCase {
    func testDatabasePoolCreatesWalShm() throws {
        let dbPool = try makeDatabasePool(filename: "database.sqlite")
        withExtendedLifetime(dbPool) {
            let fm = FileManager()
            XCTAssertTrue(fm.fileExists(atPath: dbPool.path + "-wal"))
            XCTAssertTrue(fm.fileExists(atPath: dbPool.path + "-shm"))
        }
    }
    
    func testDatabasePoolDestroysWalShmOnClosing() throws {
        // ... unless SQLITE_FCNTL_PERSIST_WAL is enabled
        let path: String
        let persistentWALModeEnabled: Bool
        do {
            let dbPool = try makeDatabasePool(filename: "database.sqlite")
            persistentWALModeEnabled = try dbPool.writeWithoutTransaction { db in
                var flag: CInt = -1
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
                return flag == 1
            }
            path = dbPool.path
        }
        let fm = FileManager()
        XCTAssertTrue(fm.fileExists(atPath: path))
        if !persistentWALModeEnabled {
            XCTAssertFalse(fm.fileExists(atPath: path + "-wal"))
            XCTAssertFalse(fm.fileExists(atPath: path + "-shm"))
        }
    }
    
    func testPersistentWALModeEnabled() throws {
        let path: String
        do {
            var configuration = Configuration()
            configuration.prepareDatabase = { db in
                var flag: CInt = 1
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool(filename: "database.sqlite", configuration: configuration)
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
            var configuration = Configuration()
            configuration.prepareDatabase = { db in
                var flag: CInt = 0
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool(filename: "database.sqlite", configuration: configuration)
            path = dbPool.path
        }
        let fm = FileManager()
        XCTAssertTrue(fm.fileExists(atPath: path))
        XCTAssertFalse(fm.fileExists(atPath: path + "-wal"))
        XCTAssertFalse(fm.fileExists(atPath: path + "-shm"))
    }
}
