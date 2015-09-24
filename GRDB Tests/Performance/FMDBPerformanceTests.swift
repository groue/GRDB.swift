import XCTest
import GRDB

class FMDBPerformanceTests: XCTestCase {
    
    func testValueAtIndexPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longLongIntForColumnIndex(0)
                        let _ = rs.longLongIntForColumnIndex(1)
                        let _ = rs.longLongIntForColumnIndex(2)
                        let _ = rs.longLongIntForColumnIndex(3)
                        let _ = rs.longLongIntForColumnIndex(4)
                        let _ = rs.longLongIntForColumnIndex(5)
                        let _ = rs.longLongIntForColumnIndex(6)
                        let _ = rs.longLongIntForColumnIndex(7)
                        let _ = rs.longLongIntForColumnIndex(8)
                        let _ = rs.longLongIntForColumnIndex(9)
                    }
                }
            }
        }
    }
    
    func testValueNamedPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let _ = rs.longLongIntForColumn("i0")
                        let _ = rs.longLongIntForColumn("i1")
                        let _ = rs.longLongIntForColumn("i2")
                        let _ = rs.longLongIntForColumn("i3")
                        let _ = rs.longLongIntForColumn("i4")
                        let _ = rs.longLongIntForColumn("i5")
                        let _ = rs.longLongIntForColumn("i6")
                        let _ = rs.longLongIntForColumn("i7")
                        let _ = rs.longLongIntForColumn("i8")
                        let _ = rs.longLongIntForColumn("i9")
                    }
                }
            }
        }
    }
    
    func testRecordPerformance() {
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var items = [PerformanceRecord]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let dictionary = rs.resultDictionary()
                        let item = PerformanceRecord(dictionary: dictionary)
                        item.databaseEdited = false
                        items.append(item)
                    }
                }
            }
            XCTAssertEqual(items[4].i2, 1)
            XCTAssertEqual(items[4].i3, 0)
            XCTAssertEqual(items[5].i2, 2)
            XCTAssertEqual(items[5].i3, 1)
        }
    }
}
