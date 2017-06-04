import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    
    override func encode(to container: inout PersistenceContainer) {
        container["name"] = name
        container["email"] = email
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        insertedRowIDColumn = column
    }
}

class RecordPrimaryKeyNoneTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createItem", migrate: Item.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(name: "Table")
            try record.insert(db)
            XCTAssertTrue(record.insertedRowIDColumn == nil)
            try record.insert(db)
            
            let names = try String.fetchAll(db, "SELECT name FROM items")
            XCTAssertEqual(names, ["Table", "Table"])
        }
    }


    // MARK: - Save

    func testSaveInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(name: "Table")
            try record.save(db)
            try record.save(db)
            
            let names = try String.fetchAll(db, "SELECT name FROM items")
            XCTAssertEqual(names, ["Table", "Table"])
        }
    }


    // MARK: - Fetch With Key
    
    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(email: "item@example.com")
            try record.insert(db)
            
            let fetchedRecord = try Item.fetchOne(db, key: ["email": record.email])!
            XCTAssertTrue(fetchedRecord.email == record.email)
        }
    }


    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
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
                let cursor = try Item.fetchCursor(db, keys: ids)
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let ids = [id1, id2]
                let cursor = try Item.fetchCursor(db, keys: ids)!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.name! }), Set([record1, record2].map { $0.name! }))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithPrimaryKeys() throws {
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
                let fetchedRecords = try Item.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [id1, id2]
                let fetchedRecords = try Item.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.name! }), Set([record1, record2].map { $0.name! }))
            }
        }
    }

    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(name: "Table")
            try record.insert(db)
            let id = db.lastInsertedRowID
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try Item.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Item.fetchOne(db, key: id)!
                XCTAssertTrue(fetchedRecord.name == record.name)
            }
        }
    }
}
