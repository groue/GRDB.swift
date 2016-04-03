import XCTest
import GRDB

class GRDBTestCase: XCTestCase {
    // The default configuration for tests
    var dbConfiguration: Configuration!
    
    // Builds a database queue
    func makeDatabaseQueue(filename: String = "db.sqlite") throws -> DatabaseQueue {
        try! NSFileManager.defaultManager().createDirectoryAtPath(dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        let dbQueuePath = (dbDirectoryPath as NSString).stringByAppendingPathComponent(filename)
        let dbQueue = try DatabaseQueue(path: dbQueuePath, configuration: dbConfiguration)
        try setUpDatabase(dbQueue)
        return dbQueue
    }
    
    // Subclasses can override
    func setUpDatabase(dbWriter: DatabaseWriter) throws {
    }
    
    // The default path for database pool directory
    var dbDirectoryPath: String!

    // The default path for database pool
    var dbPoolPath: String {
        return (dbDirectoryPath as NSString).stringByAppendingPathComponent("db.sqlite")
    }
    
    // The default database pool
    var dbPool: DatabasePool! {
        get {
            if let _dbPool = _dbPool {
                return _dbPool
            } else {
                try! NSFileManager.defaultManager().createDirectoryAtPath(dbDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                _dbPool = try! DatabasePool(path: dbPoolPath, configuration: dbConfiguration)
                return _dbPool!
            }
        }
        set {
            _dbPool = newValue
        }
    }
    var _dbPool: DatabasePool?
    
    
    var sqlQueries: [String]!
    var lastSQLQuery: String!
    
    override func setUp() {
        super.setUp()

        let dbPoolDirectoryName = "GRDBTestCase-\(NSProcessInfo.processInfo().globallyUniqueString)"
        dbDirectoryPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(dbPoolDirectoryName)
        
        dbConfiguration = Configuration()
        dbConfiguration.trace = { (sql) in
            self.sqlQueries.append(sql)
            self.lastSQLQuery = sql
            // LogSQL(sql) // Uncomment for verbose tests
        }
        sqlQueries = []
        lastSQLQuery = nil
        
        do { try NSFileManager.defaultManager().removeItemAtPath(dbDirectoryPath) } catch { }
    }
    
    override func tearDown() {
        super.tearDown()
        
        _dbPool = nil
                
        do { try NSFileManager.defaultManager().removeItemAtPath(dbDirectoryPath) } catch { }
    }
    
    func assertNoError(file: StaticString = #file, line: UInt = #line, @noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error at \(file):\(line): \(error)")
        }
    }
    
    func sql<T>(databaseReader: DatabaseReader, _ request: FetchRequest<T>) -> String {
        return databaseReader.read { db in
            _ = Row.fetchOne(db, request)
            return self.lastSQLQuery
        }
    }
}
