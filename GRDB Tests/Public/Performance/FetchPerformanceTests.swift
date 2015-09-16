import XCTest
import GRDB

class FetchPerformanceTests: XCTestCase {
    var dbQueue: DatabaseQueue!
    
    override func setUp() {
        super.setUp()

        // Populate Database
        
        let databasePath = NSBundle(forClass: self.dynamicType).pathForResource("FetchPerformanceTests", ofType: "sqlite")!
        let configuration = Configuration(readonly: true)
        dbQueue = try! DatabaseQueue(path: databasePath, configuration: configuration)
    }
    
    override func tearDown() {
        super.tearDown()
        dbQueue = nil
    }
    
    func testUnsafeFetchAndRawValuePerformance() {
        var sum: Int64 = 0
        self.measureBlock {
            self.dbQueue.inDatabase { db in
                for row in Row.unsafeFetch(db, "SELECT * FROM items") {
                    let i0 = row.int64(atIndex: 0)
                    let i1 = row.int64(atIndex: 1)
                    let i2 = row.int64(atIndex: 2)
                    let i3 = row.int64(atIndex: 3)
                    let i4 = row.int64(atIndex: 4)
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
        }
        XCTAssertEqual(sum, 2500750000)
    }
    
    func testRegularFetchAndRawValuePerformance() {
        var sum: Int64 = 0
        self.measureBlock {
            self.dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let i0 = row.int64(atIndex: 0)
                    let i1 = row.int64(atIndex: 1)
                    let i2 = row.int64(atIndex: 2)
                    let i3 = row.int64(atIndex: 3)
                    let i4 = row.int64(atIndex: 4)
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
        }
        XCTAssertEqual(sum, 2500750000)
    }
    
    func testRegularFetchAndRegularValuePerformance() {
        var sum: Int64 = 0
        self.measureBlock {
            self.dbQueue.inDatabase { db in
                for row in Row.fetch(db, "SELECT * FROM items") {
                    let i0: Int64 = row.value(atIndex: 0)!
                    let i1: Int64 = row.value(atIndex: 1)!
                    let i2: Int64 = row.value(atIndex: 2)!
                    let i3: Int64 = row.value(atIndex: 3)!
                    let i4: Int64 = row.value(atIndex: 4)!
                    sum += i0 + i1 + i2 + i3 + i4
                }
            }
        }
        XCTAssertEqual(sum, 2500750000)
    }
    
}
