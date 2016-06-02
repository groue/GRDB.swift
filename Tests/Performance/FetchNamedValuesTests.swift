import XCTest
import GRDB
import SQLite

private let expectedRowCount = 100_000

/// Here we test the extraction of values by column name.
class FetchNamedValuesTests: XCTestCase {
    
    func testFMDB() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        _ = rs.longForColumn("i0")
                        _ = rs.longForColumn("i1")
                        _ = rs.longForColumn("i2")
                        _ = rs.longForColumn("i3")
                        _ = rs.longForColumn("i4")
                        _ = rs.longForColumn("i5")
                        _ = rs.longForColumn("i6")
                        _ = rs.longForColumn("i7")
                        _ = rs.longForColumn("i8")
                        _ = rs.longForColumn("i9")
                        
                        count += 1
                    }
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testGRDB() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let dbQueue = try! DatabaseQueue(path: databasePath)
        
        measureBlock {
            var count = 0
            
            dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    _ = row.value(named: "i0") as Int
                    _ = row.value(named: "i1") as Int
                    _ = row.value(named: "i2") as Int
                    _ = row.value(named: "i3") as Int
                    _ = row.value(named: "i4") as Int
                    _ = row.value(named: "i5") as Int
                    _ = row.value(named: "i6") as Int
                    _ = row.value(named: "i7") as Int
                    _ = row.value(named: "i8") as Int
                    _ = row.value(named: "i9") as Int
                    
                    count += 1
                }
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
    func testSQLiteSwift() {
        let databasePath = NSBundle(for: self.dynamicType).pathForResource("PerformanceTests", ofType: "sqlite")!
        let db = try! Connection(databasePath)
        
        self.measureBlock {
            var count = 0
            
            for item in try! db.prepare(itemsTable) {
                _ = item[i0Column]
                _ = item[i1Column]
                _ = item[i2Column]
                _ = item[i3Column]
                _ = item[i4Column]
                _ = item[i5Column]
                _ = item[i6Column]
                _ = item[i7Column]
                _ = item[i8Column]
                _ = item[i9Column]
                
                count += 1
            }
            
            XCTAssertEqual(count, expectedRowCount)
        }
    }
    
}
