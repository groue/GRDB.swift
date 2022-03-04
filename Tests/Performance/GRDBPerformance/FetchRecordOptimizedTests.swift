import XCTest
import GRDB

private let expectedRowCount = 200_000

/// A record optimized for fetching performance
private struct Item: Codable, FetchableRecord, PersistableRecord {
    var i0: Int
    var i1: Int
    var i2: Int
    var i3: Int
    var i4: Int
    var i5: Int
    var i6: Int
    var i7: Int
    var i8: Int
    var i9: Int
    
    init(row: Row) throws {
        i0 = try row[0]
        i1 = try row[1]
        i2 = try row[2]
        i3 = try row[3]
        i4 = try row[4]
        i5 = try row[5]
        i6 = try row[6]
        i7 = try row[7]
        i8 = try row[8]
        i9 = try row[9]
    }
    
    static let databaseSelection: [SQLSelectable] = [
        Column("i0"),
        Column("i1"),
        Column("i2"),
        Column("i3"),
        Column("i4"),
        Column("i5"),
        Column("i6"),
        Column("i7"),
        Column("i8"),
        Column("i9"),
    ]
}

/// Here we test the extraction of a plain Swift struct
class FetchRecordOptimizedTests: XCTestCase {
    func testGRDB() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        let options = XCTMeasureOptions()
        options.iterationCount = 50
        measure(options: options) {
            let items = try! dbQueue.inDatabase { db in
                try Item.fetchAll(db)
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
}
