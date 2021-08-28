import XCTest
import GRDB

private let insertedRowCount = 20_000

/// A record optimized for batch insert performance
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
    
    static func optimizedInsertStatement(_ db: Database) throws -> Statement {
        try db.makeStatement(literal: """
            INSERT INTO \(self) (
              \(CodingKeys.i0),
              \(CodingKeys.i1),
              \(CodingKeys.i2),
              \(CodingKeys.i3),
              \(CodingKeys.i4),
              \(CodingKeys.i5),
              \(CodingKeys.i6),
              \(CodingKeys.i7),
              \(CodingKeys.i8),
              \(CodingKeys.i9))
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
    }
    
    func insert(with statement: Statement) throws {
        statement.setUncheckedArguments([
            i0,
            i1,
            i2,
            i3,
            i4,
            i5,
            i6,
            i7,
            i8,
            i9])
        try statement.execute()
    }
}

class InsertRecordOptimizedTests: XCTestCase {
    func testGRDB() {
        let databaseFileName = "GRDBPerformanceTests-\(ProcessInfo.processInfo.globallyUniqueString).sqlite"
        let databasePath = (NSTemporaryDirectory() as NSString).appendingPathComponent(databaseFileName)
        _ = try? FileManager.default.removeItem(atPath: databasePath)
        defer {
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item")!, insertedRowCount)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MIN(i0) FROM item")!, 0)
                XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT MAX(i9) FROM item")!, insertedRowCount - 1)
            }
            try! FileManager.default.removeItem(atPath: databasePath)
        }
        
        let options = XCTMeasureOptions()
        options.iterationCount = 50
        measure(options: options) {
            _ = try? FileManager.default.removeItem(atPath: databasePath)
            
            let dbQueue = try! DatabaseQueue(path: databasePath)
            try! dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE item (i0 INT, i1 INT, i2 INT, i3 INT, i4 INT, i5 INT, i6 INT, i7 INT, i8 INT, i9 INT)")
            }
            
            try! dbQueue.inTransaction { db in
                let statement = try Item.optimizedInsertStatement(db)
                for i in 0..<insertedRowCount {
                    let item = Item(i0: i, i1: i, i2: i, i3: i, i4: i, i5: i, i6: i, i7: i, i8: i, i9: i)
                    try item.insert(with: statement)
                }
                return .commit
            }
        }
    }
}
