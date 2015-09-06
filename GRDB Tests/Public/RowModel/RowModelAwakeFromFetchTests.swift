import XCTest
import GRDB

class EventRecorder : RowModel {
    var id: Int64?
    var awakeFromFetchCount = 0
    
    override static func databaseTableName() -> String? {
        return "eventRecorders"
    }
    
    override func updateFromRow(row: Row) {
        for (column, dbv) in row {
            switch column {
            case "id": id = dbv.value()
            default: break
            }
        }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    override func awakeFromFetch() {
        awakeFromFetchCount += 1
        super.awakeFromFetch()
    }
}

class RowModelEventsTests: GRDBTestCase {
    
    func testAwakeFromFetchIsNotTriggeredByInit() {
        let rowModel = EventRecorder()
        XCTAssertEqual(rowModel.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsNotTriggeredByInitFromRow() {
        let rowModel = EventRecorder(row:Row(dictionary:[:]))
        XCTAssertEqual(rowModel.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsTriggeredByFetch() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
                do {
                    let rowModel = EventRecorder()
                    try rowModel.insert(db)
                    XCTAssertEqual(rowModel.awakeFromFetchCount, 0)
                    try rowModel.reload(db)
                    XCTAssertEqual(rowModel.awakeFromFetchCount, 1)
                }
            }
        }
    }
    func testAwakeFromFetchIsTriggeredByReload() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
                try EventRecorder().insert(db)
                do {
                    let rowModel = EventRecorder.fetchOne(db, "SELECT * FROM eventRecorders")!
                    XCTAssertEqual(rowModel.awakeFromFetchCount, 1)
                }
            }
        }
    }
}
