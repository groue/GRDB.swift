import XCTest
import GRDB

class EventRecorder : Record {
    var id: Int64?
    var awakeFromFetchCount = 0
    
    override static func databaseTableName() -> String? {
        return "eventRecorders"
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["id"] { id = dbv.value() }
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

class RecordEventsTests: GRDBTestCase {
    
    func testAwakeFromFetchIsNotTriggeredByInit() {
        let record = EventRecorder()
        XCTAssertEqual(record.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsNotTriggeredByInitFromRow() {
        let record = EventRecorder(row:Row(dictionary:[:]))
        XCTAssertEqual(record.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsTriggeredByFetch() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
                do {
                    let record = EventRecorder()
                    try record.insert(db)
                    XCTAssertEqual(record.awakeFromFetchCount, 0)
                    try record.reload(db)
                    XCTAssertEqual(record.awakeFromFetchCount, 1)
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
                    let record = EventRecorder.fetchOne(db, "SELECT * FROM eventRecorders")!
                    XCTAssertEqual(record.awakeFromFetchCount, 1)
                }
            }
        }
    }
}
