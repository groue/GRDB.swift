import XCTest
import GRDB

// Item has no primary key.
class Item: RowModel {
    var name: String?
    
    override class var databaseTable: Table? {
        return Table(named: "items")
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "name":    name = dbv.value()
        default:        super.setDatabaseValue(dbv, forColumn: column)
        }
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

class PrimaryKeyNoneTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.insert(db)
                try rowModel.insert(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.save(db)
                try rowModel.save(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.insert(db)
                
                let fetchedRowModel = Item.fetchOne(db, key: ["name": rowModel.name])!
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
            }
        }
    }
}
