import XCTest
import SQLite3
import GRDB
#if GRDB_COMPARE
import SQLite
#endif

private let expectedRowCount = 100_000

/// Here we test the extraction of models from rows
class FetchRecordCodableTests: XCTestCase {

    func testGRDB() throws {
        let databasePath = Bundle(for: type(of: self)).path(forResource: "PerformanceTests", ofType: "sqlite")!
        let dbQueue = try DatabaseQueue(path: databasePath)
        
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
