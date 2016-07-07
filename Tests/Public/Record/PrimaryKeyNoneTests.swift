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
    var email: String?
    
    init(name: String? = nil, email: String? = nil) {
        self.name = name
        self.email = email
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE items (" +
                "name TEXT," +
                "email TEXT UNIQUE" +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "items"
    }
    
    required init(row: Row) {
        name = row.value(named: "name")
        email = row.value(named: "email")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "email": email]
    }
}

class PrimaryKeyNoneTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createItem", migrate: Item.setup)
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
    
    func testFetchOneWithKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Item(email: "item@example.com")
                try record.insert(db)
                
                let fetchedRecord = Item.fetchOne(db, key: ["email": record.email])!
                XCTAssertTrue(fetchedRecord.email == record.email)
            }
        }
    }
}
