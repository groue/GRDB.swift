import XCTest
import GRDB

class FMDBPerformanceTests: XCTestCase {
    
    func testValueAtIndexPerformance() {
        // Here we test the extraction of values by column index.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
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
    
    func testValueNamedPerformance() {
        // Here we test the extraction of values by column name.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
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
                    }
                }
            }
        }
    }
    
    func testRecordPerformance() {
        // Here we test the loading of an array of Records.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var records = [PerformanceRecord]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        let dictionary = rs.resultDictionary()
                        let record = PerformanceRecord(dictionary: dictionary)
                        records.append(record)
                    }
                }
            }
            XCTAssertEqual(records[4].i2, 1)
            XCTAssertEqual(records[4].i3, 0)
            XCTAssertEqual(records[5].i2, 2)
            XCTAssertEqual(records[5].i3, 1)
        }
    }
    
    func testKeyValueCodingPerformance() {
        // Here we test the loading of an array of KVC-based objects.
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let dbQueue = FMDatabaseQueue(path: databasePath)
        
        self.measureBlock {
            var records = [PerformanceObjCRecord]()
            dbQueue.inDatabase { db in
                if let rs = db.executeQuery("SELECT * FROM items", withArgumentsInArray: nil) {
                    while rs.next() {
                        records.append(PerformanceObjCRecord(dictionary: rs.resultDictionary()))
                    }
                }
            }
            XCTAssertEqual(records[4].i2!.intValue, 1)
            XCTAssertEqual(records[4].i3!.intValue, 0)
            XCTAssertEqual(records[5].i2!.intValue, 2)
            XCTAssertEqual(records[5].i3!.intValue, 1)
        }
    }
}
