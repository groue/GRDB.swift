import XCTest
import GRDB

// Item has no primary key.
class Item: Record {
    var name: String?
    
    override class func databaseTableName() -> String? {
        return "items"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    init (name: String? = nil) {
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE items (" +
                "name NOT NULL" +
            ")")
    }
}

class PrimaryKeyNoneTests: RecordTestCase {
    
    
    // MARK: - Insert
    
    func testInsertInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.insert(db)
                try record.insert(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.save(db)
                try record.save(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.insert(db)
                
                let fetchedRecord = Item.fetchOne(db, key: ["name": record.name])!
                XCTAssertTrue(fetchedRecord.name == record.name)
            }
        }
    }
}
