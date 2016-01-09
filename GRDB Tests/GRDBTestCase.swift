import XCTest
import GRDB

class GRDBTestCase: XCTestCase {
    var databasePath: String!
    var dbQueue: DatabaseQueue!
    var sqlQueries: [String]!
    var dbConfiguration: Configuration {
        var dbConfiguration = Configuration()
        dbConfiguration.trace = { (sql) in
            self.sqlQueries.append(sql)
            // LogSQL(sql) // Uncomment for verbose tests
        }
        return dbConfiguration
    }
    
    override func setUp() {
        super.setUp()
        
        sqlQueries = []
        
        let databaseFileName = "GRDBTestCase-\(NSProcessInfo.processInfo().globallyUniqueString).sqlite"
        databasePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(databaseFileName)
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        dbQueue = try! DatabaseQueue(path: databasePath, configuration: dbConfiguration)
    }
    
    override func tearDown() {
        super.tearDown()
        
        dbQueue = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
    }
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
