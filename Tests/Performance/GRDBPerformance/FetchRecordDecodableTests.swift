import XCTest
import GRDB

private let expectedRowCount = 200_000

/// Here we test the extraction of Decodable GRDB records.
class FetchRecordDecodableTests: XCTestCase {

    func testGRDB() throws {
        struct Item: Decodable, FetchableRecord, TableRecord {
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
        }
        
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        measure {
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
