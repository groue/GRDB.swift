import XCTest
import GRDB

class DatabasePoolTests: XCTestCase {
    var databaseDirectoryPath: String!
    var dbPool: DatabasePool!
    var sqlQueries: [String]!
    var lastSQLQuery: String!
    
    override func setUp() {
        super.setUp()
        let databaseDirectoryName = "GRDBDatabasePoolTests-\(NSProcessInfo.processInfo().globallyUniqueString)"
        databaseDirectoryPath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseDirectoryName)
        do { try NSFileManager.defaultManager().removeItemAtPath(databaseDirectoryPath) } catch { }
        try! NSFileManager.defaultManager().createDirectoryAtPath(databaseDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        
        sqlQueries = []
        var configuration = Configuration()
        configuration.trace = { (sql) in
            self.sqlQueries.append(sql)
            self.lastSQLQuery = sql
            // LogSQL(sql) // Uncomment for verbose tests
        }
        
        let databasePath = (databaseDirectoryPath as NSString).stringByAppendingPathComponent("db.sqlite")
        dbPool = try! DatabasePool(path: databasePath, configuration: configuration)
    }
    
    override func tearDown() {
        super.tearDown()
        
        dbPool = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databaseDirectoryPath)
    }
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
    
    func testBasicWriteRead() {
        assertNoError {
            try dbPool.write { db in
                try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db.execute("INSERT INTO items (id) VALUES (NULL)")
            }
            let id = dbPool.read { db in
                Int.fetchOne(db, "SELECT id FROM items")!
            }
            XCTAssertEqual(id, 1)
        }
    }
}
