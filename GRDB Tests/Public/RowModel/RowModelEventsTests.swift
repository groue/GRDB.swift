import XCTest
import GRDB

class EventRecorder : RowModel {
    var id: Int64?
    var didFetchCount = 0
    
    override static var databaseTableName: String? {
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
    
    override func didFetch() {
        didFetchCount += 1
        super.didFetch()
    }
}

class RowModelEventsTests: GRDBTestCase {
    
    func testDidFetchIsNotTriggeredByInit() {
        let rowModel = EventRecorder()
        XCTAssertEqual(rowModel.didFetchCount, 0)
    }
    
    func testDidFetchIsNotTriggeredByInitFromRow() {
        let rowModel = EventRecorder(row:Row(dictionary:[:]))
        XCTAssertEqual(rowModel.didFetchCount, 0)
    }
    
    func testDidFetchIsTriggeredByFetch() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
                do {
                    let rowModel = EventRecorder()
                    try rowModel.insert(db)
                    XCTAssertEqual(rowModel.didFetchCount, 0)
                    try rowModel.reload(db)
                    XCTAssertEqual(rowModel.didFetchCount, 1)
                }
            }
        }
    }
    func testDidFetchIsTriggeredByReload() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
                try EventRecorder().insert(db)
                do {
                    let rowModel = EventRecorder.fetchOne(db, "SELECT * FROM eventRecorders")!
                    XCTAssertEqual(rowModel.didFetchCount, 1)
                }
            }
        }
    }
}
