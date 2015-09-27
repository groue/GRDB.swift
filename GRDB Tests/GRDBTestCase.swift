import XCTest
import GRDB

class GRDBTestCase: XCTestCase {
    var databasePath: String!
    var dbQueue: DatabaseQueue!
    var sqlQueries: [String]!
    let transactionLogger = TransactionLogger()
    
    override func setUp() {
        super.setUp()
        
        sqlQueries = []
        databasePath = "/tmp/GRDB.sqlite"
        do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
        let configuration = Configuration(trace: { (sql, arguments) in
            self.sqlQueries.append(sql)
            if let arguments = arguments {
                NSLog("GRDB: %@ -- arguments: %@", sql, arguments.description)
            } else {
                NSLog("GRDB: %@", sql)
            }
        })
        dbQueue = try! DatabaseQueue(path: databasePath, configuration: configuration)
        dbQueue.inDatabase { db in
            db.transactionDelegate = self.transactionLogger
        }
    }
    
    override func tearDown() {
        super.tearDown()
        
        dbQueue = nil
        try! NSFileManager.defaultManager().removeItemAtPath(databasePath)
    }
    
    func assertNoError(@noescape test: (Void) throws -> Void) {
        do {
            try test()
        } catch let error as DatabaseError {
            XCTFail(error.description)
        } catch let error as RecordError {
            XCTFail(error.description)
        } catch {
            XCTFail("error: \(error)")
        }
    }
}

// EXPERIMENTAL
class TransactionLogger : DatabaseTransactionDelegate {
    var events: [DatabaseEvent] = []
    
    func databaseDidChangeWithEvent(event: DatabaseEvent) {
        events.append(event)
    }
    
    func databaseWillCommit() {
        guard events.count > 0 else {
            return
        }
        
        print("DATABASE DID COMMIT")
        for event in events {
            switch event.kind {
            case .Insert:
                print("-> INSERT \(event.tableName) \(event.rowID)")
            case .Delete:
                print("-> DELETE \(event.tableName) \(event.rowID)")
            case .Update:
                print("-> UPDATE \(event.tableName) \(event.rowID)")
            }
        }
    }
    
    func databaseWillRollback() {
        events.removeAll()
    }
}
