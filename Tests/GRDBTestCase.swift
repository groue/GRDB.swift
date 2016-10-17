import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher // @testable so that we have access to SQLiteConnectionWillClose
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite // @testable so that we have access to SQLiteConnectionWillClose
#else
    @testable import GRDB       // @testable so that we have access to SQLiteConnectionWillClose
    #if os(OSX)
        import SQLiteMacOSX
    #elseif os(iOS)
        #if (arch(i386) || arch(x86_64))
            import SQLiteiPhoneSimulator
        #else
            import SQLiteiPhoneOS
        #endif
    #endif
#endif

class GRDBTestCase: XCTestCase {
    // The default configuration for tests
    var dbConfiguration: Configuration!
    
    // Builds a database queue based on dbConfiguration
    func makeDatabaseQueue(filename: String = "db.sqlite") throws -> DatabaseQueue {
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent(filename)
        let dbQueue = try DatabaseQueue(path: dbPath, configuration: dbConfiguration)
        try setup(dbQueue)
        return dbQueue
    }
    
    // Builds a database pool based on dbConfiguration
    func makeDatabasePool(filename: String = "db.sqlite") throws -> DatabasePool {
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent(filename)
        let dbPool = try DatabasePool(path: dbPath, configuration: dbConfiguration)
        try setup(dbPool)
        return dbPool
    }
    
    // Subclasses can override
    // Default implementation is empty.
    func setup(_ dbWriter: DatabaseWriter) throws {
    }
    
    // The default path for database pool directory
    private var dbDirectoryPath: String!
    
    // Populated by default configuration
    var sqlQueries: [String]!   // TODO: protect against concurrent accesses
    
    // Populated by default configuration
    var lastSQLQuery: String! {
        return sqlQueries.last!
    }
    
    override func setUp() {
        super.setUp()
        
        let dbPoolDirectoryName = "GRDBTestCase-\(ProcessInfo.processInfo.globallyUniqueString)"
        dbDirectoryPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(dbPoolDirectoryName)
        do { try FileManager.default.removeItem(atPath: dbDirectoryPath) } catch { }
        
        dbConfiguration = Configuration()
        
        // Test that database are deallocated in a clean state
        dbConfiguration.SQLiteConnectionWillClose = { sqliteConnection in
            // https://www.sqlite.org/capi3ref.html#sqlite3_close:
            // > If sqlite3_close_v2() is called on a database connection that still
            // > has outstanding prepared statements, BLOB handles, and/or
            // > sqlite3_backup objects then it returns SQLITE_OK and the
            // > deallocation of resources is deferred until all prepared
            // > statements, BLOB handles, and sqlite3_backup objects are also
            // > destroyed.
            //
            // Let's assert that there is no longer any busy update statements.
            //
            // SQLite would allow that. But not GRDB, since all updates happen
            // in closures that retain database connections, preventing
            // Database.deinit to fire.
            //
            // What we gain from this test is a guarantee that database
            // deallocation implies that there is no pending lock in the
            // database.
            //
            // See:
            // - sqlite3_next_stmt https://www.sqlite.org/capi3ref.html#sqlite3_next_stmt
            // - sqlite3_stmt_busy https://www.sqlite.org/capi3ref.html#sqlite3_stmt_busy
            // - sqlite3_stmt_readonly https://www.sqlite.org/capi3ref.html#sqlite3_stmt_readonly
            var stmt: SQLiteStatement? = sqlite3_next_stmt(sqliteConnection, nil)
            while stmt != nil {
                XCTAssertTrue(sqlite3_stmt_readonly(stmt) != 0 || sqlite3_stmt_busy(stmt) == 0)
                stmt = sqlite3_next_stmt(sqliteConnection, stmt)
            }
        }
        
        dbConfiguration.trace = { [unowned self] sql in
            self.sqlQueries.append(sql)
        }
        
        #if GRDBCIPHER_USE_ENCRYPTION
            // We are testing encrypted databases.
            dbConfiguration.passphrase = "secret"
        #endif
        
        sqlQueries = []
    }
    
    override func tearDown() {
        super.tearDown()
        do { try FileManager.default.removeItem(atPath: dbDirectoryPath) } catch { }
    }
    
    func assertNoError(file: StaticString = #file, line: UInt = #line, _ test: (Void) throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error at \(file):\(line): \(error)")
        }
    }
    
    func assertDidExecute(sql: String) {
        XCTAssertTrue(sqlQueries.contains(sql), "Did not execute \(sql)")
    }
    
    func sql(_ databaseReader: DatabaseReader, _ request: FetchRequest) -> String {
        return databaseReader.read { db in
            _ = Row.fetchOne(db, request)
            return lastSQLQuery
        }
    }
}
