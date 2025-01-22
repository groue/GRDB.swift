// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif


#if !GRDB_SQLITE_INLINE
extension GRDBTestCase : SQLiteAPI { public typealias SQLI = DefaultSQLiteInterface }
#endif

import Foundation
import XCTest
@testable import GRDB

// Support for Database.logError
struct SQLiteDiagnostic {
    var resultCode: ResultCode
    var message: String
}
private let lastSQLiteDiagnosticMutex = Mutex<SQLiteDiagnostic?>(nil)
var lastSQLiteDiagnostic: SQLiteDiagnostic? { lastSQLiteDiagnosticMutex.load() }
let logErrorSetup: Void = {
    Database.logError = { (resultCode, message) in
        lastSQLiteDiagnosticMutex.store(SQLiteDiagnostic(resultCode: resultCode, message: message))
    }
}()

class GRDBTestCase: XCTestCase {
    // The default configuration for tests
    var dbConfiguration: Configuration!
    
    // Builds a database queue based on dbConfiguration
    func makeDatabaseQueue(filename: String? = nil) throws -> DatabaseQueue {
        try makeDatabaseQueue(filename: filename, configuration: dbConfiguration)
    }
    
    // Builds a database queue
    func makeDatabaseQueue(filename: String? = nil, configuration: Configuration) throws -> DatabaseQueue {
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent(filename ?? ProcessInfo.processInfo.globallyUniqueString)
        let dbQueue = try DatabaseQueue(path: dbPath, configuration: configuration)
        try setup(dbQueue)
        return dbQueue
    }
    
    // Builds a database pool based on dbConfiguration
    func makeDatabasePool(filename: String? = nil) throws -> DatabasePool {
        try makeDatabasePool(filename: filename, configuration: dbConfiguration)
    }
    
    // Builds a database pool
    func makeDatabasePool(filename: String? = nil, configuration: Configuration) throws -> DatabasePool {
        try FileManager.default.createDirectory(atPath: dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let dbPath = (dbDirectoryPath as NSString).appendingPathComponent(filename ?? ProcessInfo.processInfo.globallyUniqueString)
        let dbPool = try DatabasePool(path: dbPath, configuration: configuration)
        try setup(dbPool)
        return dbPool
    }
    
    // Subclasses can override
    // Default implementation is empty.
    func setup(_ dbWriter: some DatabaseWriter) throws {
    }
    
    // The default path for database pool directory
    private var dbDirectoryPath: String!
    
    let _sqlQueriesMutex: Mutex<[String]> = Mutex([])
    
    // Automatically updated by default dbConfiguration
    var sqlQueries: [String] { _sqlQueriesMutex.load() }
    
    // Automatically updated by default dbConfiguration
    var lastSQLQuery: String? { sqlQueries.last }
    
    override func setUp() {
        super.setUp()
        
        _ = logErrorSetup
        
        let dbPoolDirectoryName = "GRDBTestCase-\(ProcessInfo.processInfo.globallyUniqueString)"
        dbDirectoryPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(dbPoolDirectoryName)
        do { try FileManager.default.removeItem(atPath: dbDirectoryPath) } catch { }
        
        dbConfiguration = Configuration()
        
        // Test that database are deallocated in a clean state
        dbConfiguration.onConnectionWillClose { sqliteConnection in
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
            var stmt: SQLiteStatement? = SQLite3.sqlite3_next_stmt(sqliteConnection, nil)
            while stmt != nil {
                XCTAssertTrue(SQLite3.sqlite3_stmt_readonly(stmt) != 0 || SQLite3.sqlite3_stmt_busy(stmt) == 0)
                stmt = SQLite3.sqlite3_next_stmt(sqliteConnection, stmt)
            }
        }
        
        dbConfiguration.prepareDatabase { [_sqlQueriesMutex] db in
            db.trace { event in
                _sqlQueriesMutex.withLock {
                    $0.append(event.expandedDescription)
                }
            }
            
            #if GRDBCIPHER_USE_ENCRYPTION
            try db.usePassphrase("secret")
            #endif
        }
        
        clearSQLQueries()
    }
    
    override func tearDown() {
        super.tearDown()
        do { try FileManager.default.removeItem(atPath: dbDirectoryPath) } catch { }
    }
    
    func clearSQLQueries() {
        _sqlQueriesMutex.store([])
    }
    
    func assertNoError(file: StaticString = #file, line: UInt = #line, _ test: () throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error: \(error)", file: file, line: line)
        }
    }
    
    func assertDidExecute(sql: String, file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(sqlQueries.contains(sql), "Did not execute \(sql)", file: file, line: line)
    }
    
    func assert(_ record: some EncodableRecord, isEncodedIn row: Row, file: StaticString = #file, line: UInt = #line) throws {
        let recordDict = try record.databaseDictionary
        let rowDict = Dictionary(row, uniquingKeysWith: { (left, _) in left })
        XCTAssertEqual(recordDict, rowDict, file: file, line: line)
    }
    
    // Compare SQL strings (ignoring leading and trailing white space and semicolons.
    func assertEqualSQL(_ lhs: String, _ rhs: String, file: StaticString = #file, line: UInt = #line) {
        // Trim white space and ";"
        let cs = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";"))
        XCTAssertEqual(lhs.trimmingCharacters(in: cs), rhs.trimmingCharacters(in: cs), file: file, line: line)
    }
    
    // Compare SQL strings (ignoring leading and trailing white space and semicolons.
    func assertEqualSQL(
        _ db: Database,
        _ request: some FetchRequest,
        _ sql: String,
        file: StaticString = #file,
        line: UInt = #line)
    throws
    {
        try request.makeStatement(db).makeCursor().next()
        assertEqualSQL(lastSQLQuery!, sql, file: file, line: line)
    }
    
    // Compare SQL strings.
    func assertEqualSQL(
        _ db: Database,
        _ expression: some SQLExpressible,
        _ sql: String,
        file: StaticString = #file,
        line: UInt = #line)
    throws
    {
        let request: SQLRequest<Row> = "SELECT \(expression)"
        try assertEqualSQL(db, request, "SELECT \(sql)", file: file, line: line)
    }
    
    // Compare SQL strings (ignoring leading and trailing white space and semicolons.
    func assertEqualSQL(
        _ databaseReader: some DatabaseReader,
        _ request: some FetchRequest,
        _ sql: String,
        file: StaticString = #file,
        line: UInt = #line)
    throws
    {
        try databaseReader.unsafeRead { db in
            try assertEqualSQL(db, request, sql, file: file, line: line)
        }
    }

    func sql(
        _ databaseReader: some DatabaseReader,
        _ request: some FetchRequest)
    -> String
    {
        try! databaseReader.unsafeRead { db in
            try request.makeStatement(db).makeCursor().next()
            return lastSQLQuery!
        }
    }
}

#if SWIFT_PACKAGE
let testBundle = Bundle.module
#else
let testBundle = Bundle(for: GRDBTestCase.self)
#endif

extension FetchRequest {
    /// Turn request into a statement
    func makeStatement(_ db: Database) throws -> Statement {
        try makePreparedRequest(db, forSingleResult: false).statement
    }
    
    /// Turn request into SQL and arguments
    func build(_ db: Database) throws -> (sql: String, arguments: StatementArguments) {
        let statement = try makePreparedRequest(db, forSingleResult: false).statement
        return (sql: statement.sql, arguments: statement.arguments)
    }
}

/// A type-erased ValueReducer.
struct AnyValueReducer<Fetched, Value>: ValueReducer {
    private var __fetch: @Sendable (Database) throws -> Fetched
    private var __value: (Fetched) -> Value?
    
    init(
        fetch: @escaping @Sendable (Database) throws -> Fetched,
        value: @escaping (Fetched) -> Value?)
    {
        self.__fetch = fetch
        self.__value = value
    }
    
    func _makeFetcher() -> AnyValueReducerFetcher<Fetched> {
        AnyValueReducerFetcher(fetch: __fetch)
    }
    
    func _value(_ fetched: Fetched) -> Value? {
        __value(fetched)
    }
}

/// A type-erased _ValueReducerFetcher.
struct AnyValueReducerFetcher<Fetched>: _ValueReducerFetcher {
    private var _fetch: @Sendable (Database) throws -> Fetched
    
    init(fetch: @escaping @Sendable (Database) throws -> Fetched) {
        self._fetch = fetch
    }
    
    func fetch(_ db: Database) throws -> Fetched {
        try _fetch(db)
    }
}

// Assume this is correct :-/
extension XCTestExpectation: @unchecked Sendable { }
