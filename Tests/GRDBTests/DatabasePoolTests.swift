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
            var configuration = dbConfiguration!
            configuration.prepareDatabase = { db in
                var flag: CInt = 1
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool(configuration: configuration)
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
            var configuration = dbConfiguration!
            configuration.prepareDatabase = { db in
                var flag: CInt = 0
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool(configuration: configuration)
            path = dbPool.path
        }
        let fm = FileManager()
        XCTAssertTrue(fm.fileExists(atPath: path))
        XCTAssertFalse(fm.fileExists(atPath: path + "-wal"))
        XCTAssertFalse(fm.fileExists(atPath: path + "-shm"))
    }
    
    func testReadonlyAccessWithPersistentWALModeDisabled() throws {
        // Create a WAL database without  -shm and -wal temporary files:
        let path: String
        do {
            var configuration = dbConfiguration!
            configuration.prepareDatabase = { db in
                var flag: CInt = 0
                let code = withUnsafeMutablePointer(to: &flag) { flagP in
                    sqlite3_file_control(db.sqliteConnection, nil, SQLITE_FCNTL_PERSIST_WAL, flagP)
                }
                guard code == SQLITE_OK else {
                    throw DatabaseError(resultCode: ResultCode(rawValue: code))
                }
            }
            let dbPool = try makeDatabasePool(configuration: configuration)
            path = dbPool.path
        }
        
        // CAN NOT open readonly connection to WAL database without -shm
        // and -wal temporary files:
        // https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use
        do {
            var configuration = dbConfiguration!
            configuration.readonly = true
            _ = try DatabaseQueue(path: path, configuration: configuration)
            XCTFail("Expected error")
        } catch DatabaseError.SQLITE_CANTOPEN {
        }
        
        // CAN open readonly connection to WAL database without -shm
        // and -wal temporary files, if database is declared as immutable:
        // https://www.sqlite.org/walformat.html#operations_that_require_locks_and_which_locks_those_operations_use
        do {
            var urlComponents = URLComponents(url: URL(fileURLWithPath: path), resolvingAgainstBaseURL: false)!
            urlComponents.queryItems = [URLQueryItem(name: "immutable", value: "1")]
            let immutableURL = urlComponents.url!
            
            var configuration = dbConfiguration!
            configuration.readonly = true
            _ = try DatabaseQueue(path: immutableURL.absoluteString, configuration: configuration)
        }
    }
}
