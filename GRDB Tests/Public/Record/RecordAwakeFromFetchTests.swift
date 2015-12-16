import XCTest
import GRDB

class EventRecorder : Record {
    var id: Int64?
    var awakeFromFetchCount = 0
    
    init(id: Int64? = nil) {
        self.id = id
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute("CREATE TABLE eventRecorders (id INTEGER PRIMARY KEY)")
    }
    
    // Record
    
    override static func databaseTableName() -> String {
        return "eventRecorders"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        super.init(row)
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
    
    override func awakeFromFetch(row: Row) {
        super.awakeFromFetch(row)
        awakeFromFetchCount += 1
    }
}

class RecordEventsTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createEventRecorder", migrate: EventRecorder.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testAwakeFromFetchIsNotTriggeredByInit() {
        let record = EventRecorder()
        XCTAssertEqual(record.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsNotTriggeredByInitFromRow() {
        let record = EventRecorder(Row())
        XCTAssertEqual(record.awakeFromFetchCount, 0)
    }
    
    func testAwakeFromFetchIsTriggeredByFetch() {
        assertNoError {
            try dbQueue.inDatabase { db in
                do {
                    let record = EventRecorder()
                    try record.insert(db)
                    XCTAssertEqual(record.awakeFromFetchCount, 0)
                }
            }
        }
    }
    func testAwakeFromFetchIsTriggeredByReload() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try EventRecorder().insert(db)
                do {
                    let record = EventRecorder.fetchOne(db, "SELECT * FROM eventRecorders")!
                    XCTAssertEqual(record.awakeFromFetchCount, 1)
                }
            }
        }
    }
}
