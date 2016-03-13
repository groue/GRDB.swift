import XCTest
import GRDB

class GRDBTestCase: XCTestCase {
    var dbConfiguration = Configuration()
    
    var dbQueuePath: String = {
        let dbQueueFileName = "GRDBTestCase-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        return (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(dbQueueFileName)
    }()
    var _dbQueue: DatabaseQueue?
    var dbQueue: DatabaseQueue! {
        get {
            if let _dbQueue = _dbQueue {
                return _dbQueue
            } else {
                _dbQueue = try! DatabaseQueue(path: dbQueuePath, configuration: dbConfiguration)
                return _dbQueue!
            }
        }
        set {
            _dbQueue = newValue
        }
    }
    
    var dbPoolDirectoryPath: String = {
        let dbPoolDirectoryName = "GRDBTestCase-\(NSProcessInfo.processInfo().globallyUniqueString)"
        return (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(dbPoolDirectoryName)
    }()
    var dbPoolPath: String {
        return (dbPoolDirectoryPath as NSString).stringByAppendingPathComponent("db.sqlite")
    }
    var _dbPool: DatabasePool?
    var dbPool: DatabasePool! {
        get {
            if let _dbPool = _dbPool {
                return _dbPool
            } else {
                try! NSFileManager.defaultManager().createDirectoryAtPath(dbPoolDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                _dbPool = try! DatabasePool(path: dbPoolPath, configuration: dbConfiguration)
                return _dbPool!
            }
        }
        set {
            _dbPool = newValue
        }
    }
    
    
    var sqlQueries: [String]!
    var lastSQLQuery: String!
    
    override func setUp() {
        super.setUp()
        
        dbConfiguration.trace = { (sql) in
            self.sqlQueries.append(sql)
            self.lastSQLQuery = sql
            // LogSQL(sql) // Uncomment for verbose tests
        }
        sqlQueries = []
        lastSQLQuery = nil
        
        do { try NSFileManager.defaultManager().removeItemAtPath(dbQueuePath) } catch { }
        do { try NSFileManager.defaultManager().removeItemAtPath(dbPoolDirectoryPath) } catch { }
    }
    
    override func tearDown() {
        super.tearDown()
        
        _dbQueue = nil
        _dbPool = nil
                
        do { try NSFileManager.defaultManager().removeItemAtPath(dbQueuePath) } catch { }
        do { try NSFileManager.defaultManager().removeItemAtPath(dbPoolDirectoryPath) } catch { }
    }
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
    
    func sql<T>(request: FetchRequest<T>) -> String {
        return dbQueue.inDatabase { db in
            _ = Row.fetchOne(db, request)
            return self.lastSQLQuery
        }
    }
}
