import XCTest
import GRDB
import SQLite

private let expectedRowCount = 100_000

/// Here we test the extraction of values by column name.
class FetchNamedValuesTests: XCTestCase {
    
    func testFMDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longForColumn("i0")
                        let _ = rs.longForColumn("i1")
                        let _ = rs.longForColumn("i2")
                        let _ = rs.longForColumn("i3")
                        let _ = rs.longForColumn("i4")
                        let _ = rs.longForColumn("i5")
                        let _ = rs.longForColumn("i6")
                        let _ = rs.longForColumn("i7")
                        let _ = rs.longForColumn("i8")
                        let _ = rs.longForColumn("i9")
                        
                        count += 1
                    }
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testGRDB() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let _: Int = row.value(named: "i0")
                    let _: Int = row.value(named: "i1")
                    let _: Int = row.value(named: "i2")
                    let _: Int = row.value(named: "i3")
                    let _: Int = row.value(named: "i4")
                    let _: Int = row.value(named: "i5")
                    let _: Int = row.value(named: "i6")
                    let _: Int = row.value(named: "i7")
                    let _: Int = row.value(named: "i8")
                    let _: Int = row.value(named: "i9")
                    
                    count += 1
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testSQLiteSwift() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            var count = 0
            
            for item in try! db.prepare(itemsTable) {
                let _ = item[i0Column]
                let _ = item[i1Column]
                let _ = item[i2Column]
                let _ = item[i3Column]
                let _ = item[i4Column]
                let _ = item[i5Column]
                let _ = item[i6Column]
                let _ = item[i7Column]
                let _ = item[i8Column]
                let _ = item[i9Column]
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
}
