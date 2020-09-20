import XCTest
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 100_000

/// Here we test the extraction of models from rows
class FetchRecordCodableTests: XCTestCase {

    func testGRDB() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GRDBPerformanceTests.sqlite")
        try generateSQLiteDatabaseIfMissing(at: url, insertedRowCount: expectedRowCount)
        let dbQueue = try DatabaseQueue(path: url.path)
        
        measure {
            let items = try! dbQueue.inDatabase { db in
                try ItemCodable.fetchAll(db, sql: "SELECT * FROM items")
            }
            XCTAssertEqual(items.count, expectedRowCount)
            XCTAssertEqual(items[0].i0, 0)
            XCTAssertEqual(items[1].i1, 1)
            XCTAssertEqual(items[expectedRowCount-1].i9, expectedRowCount-1)
        }
    }
}
