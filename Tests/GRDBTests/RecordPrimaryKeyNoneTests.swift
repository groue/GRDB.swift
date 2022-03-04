import XCTest
import GRDB

// Item has no primary key.
private class Item : Record, Hashable {
    var name: String?
    var email: String?
    
    var insertedRowIDColumn: String?
    
    init(name: String? = nil, email: String? = nil) {
        self.name = name
        self.email = email
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE items (
                name TEXT,
                email TEXT UNIQUE)
            """)
    }
    
    // Record
    
    override class var databaseTableName: String {
        "items"
    }
    
    required init(row: Row) throws {
        name = try row["name"]
        email = try row["email"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["name"] = name
        container["email"] = email
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        insertedRowIDColumn = column
    }
    
    static func == (lhs: Item, rhs: Item) -> Bool {
        lhs.name == rhs.name && lhs.email == rhs.email
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(email)
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
            
            let names = try String.fetchAll(db, sql: "SELECT name FROM items")
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
            
            let names = try String.fetchAll(db, sql: "SELECT name FROM items")
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
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"items\" WHERE \"email\" = 'item@example.com'")
        }
    }
    
    
    // MARK: - Fetch With Key Request
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(email: "item@example.com")
            try record.insert(db)
            
            let fetchedRecord = try Item.filter(key: ["email": record.email]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.email == record.email)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"items\" WHERE \"email\" = 'item@example.com'")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = Item.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"items\" ORDER BY \"rowid\"")
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
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [id1, id2]
                let cursor = try Item.fetchCursor(db, keys: ids)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
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
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
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
                let fetchedRecords = try Item.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [id1, id2]
                let fetchedRecords = try Item.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
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
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"items\" WHERE \"rowid\" = \(id)")
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
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
                let cursor = try Item.filter(keys: ids).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [id1, id2]
                let cursor = try Item.filter(keys: ids).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try Item.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [id1, id2]
                let fetchedRecords = try Item.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try Item.filter(keys: ids).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [id1, id2]
                let fetchedRecords = try Item.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                let fetchedNames = Set(fetchedRecords.map { $0.name! })
                let expectedNames = Set([record1, record2].map { $0.name! })
                XCTAssertEqual(fetchedNames, expectedNames)
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Item(name: "Table")
            try record.insert(db)
            let id = db.lastInsertedRowID
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try Item.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Item.filter(key: id).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"items\" WHERE \"rowid\" = \(id)")
            }
        }
    }
}
