import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Item has no primary key.
private class Item : Record {
    var name: String?
    
    init(name: String? = nil) {
        self.name = name
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE items (" +
                "name NOT NULL" +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "items"
    }
    
    required init(_ row: Row) {
        name = row.value(named: "name")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

class PrimaryKeyNoneTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createItem", migrate: Item.setupInDatabase)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.insert(db)
                try record.insert(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items")
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.save(db)
                try record.save(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items")
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.insert(db)
                
                let fetchedRecord = Item.fetchOne(db, key: ["name": record.name])!
                XCTAssertTrue(fetchedRecord.name == record.name)
            }
        }
    }
}
