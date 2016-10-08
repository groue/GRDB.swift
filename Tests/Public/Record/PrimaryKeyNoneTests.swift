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
    
    var insertedRowIDColumn: String?
    
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
    
    override class var databaseTableName: String {
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
    
    override func didInsert(with rowID: Int64, for column: String?) {
        insertedRowIDColumn = column
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
                XCTAssertTrue(record.insertedRowIDColumn == nil)
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
    
    
    // MARK: - Fetch With Key
    
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
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Item(name: "Table")
                try record1.insert(db)
                let id1 = db.lastInsertedRowID
                let record2 = Item(name: "Chair")
                try record2.insert(db)
                let id2 = db.lastInsertedRowID
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Array(Item.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [id1, id2]
                    let fetchedRecords = Array(Item.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.name! }), Set([record1, record2].map { $0.name! }))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Item(name: "Table")
                try record1.insert(db)
                let id1 = db.lastInsertedRowID
                let record2 = Item(name: "Chair")
                try record2.insert(db)
                let id2 = db.lastInsertedRowID
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Item.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [id1, id2]
                    let fetchedRecords = Item.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.name! }), Set([record1, record2].map { $0.name! }))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Item(name: "Table")
                try record.insert(db)
                let id = db.lastInsertedRowID
                
                do {
                    let id: Int64? = nil
                    let fetchedRecord = Item.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = Item.fetchOne(db, key: id)!
                    XCTAssertTrue(fetchedRecord.name == record.name)
                }
            }
        }
    }
}
