import XCTest
import GRDB
import SQLite

/// Here we test the extraction of values by column index.
class FetchPositionalValuesTests: XCTestCase {
    
    func testFMDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longForColumnIndex(0)
                        let _ = rs.longForColumnIndex(1)
                        let _ = rs.longForColumnIndex(2)
                        let _ = rs.longForColumnIndex(3)
                        let _ = rs.longForColumnIndex(4)
                        let _ = rs.longForColumnIndex(5)
                        let _ = rs.longForColumnIndex(6)
                        let _ = rs.longForColumnIndex(7)
                        let _ = rs.longForColumnIndex(8)
                        let _ = rs.longForColumnIndex(9)
                    }
                }
            }
        }
    }
    
    func testGRDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let _: Int = row.value(atIndex: 0)
                    let _: Int = row.value(atIndex: 1)
                    let _: Int = row.value(atIndex: 2)
                    let _: Int = row.value(atIndex: 3)
                    let _: Int = row.value(atIndex: 4)
                    let _: Int = row.value(atIndex: 5)
                    let _: Int = row.value(atIndex: 6)
                    let _: Int = row.value(atIndex: 7)
                    let _: Int = row.value(atIndex: 8)
                    let _: Int = row.value(atIndex: 9)
                }
            }
        }
    }
    
    func testSQLiteSwift() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            // Column access by index requires raw SQL (unlike extraction of values by column name).
            for row in db.prepare("SELECT * FROM items") {
                // Direct Int extraction is not supported.
                let _ = Int(row[0] as! Int64)
                let _ = Int(row[1] as! Int64)
                let _ = Int(row[2] as! Int64)
                let _ = Int(row[3] as! Int64)
                let _ = Int(row[4] as! Int64)
                let _ = Int(row[5] as! Int64)
                let _ = Int(row[6] as! Int64)
                let _ = Int(row[7] as! Int64)
                let _ = Int(row[8] as! Int64)
                let _ = Int(row[9] as! Int64)
            }
        }
    }
    
}
