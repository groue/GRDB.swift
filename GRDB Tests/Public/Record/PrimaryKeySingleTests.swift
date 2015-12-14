import XCTest
import GRDB

// Pet has a non-RowID primary key.
class Pet: Record {
    var UUID: String!
    var name: String!
    
    override class func databaseTableName() -> String {
        return "pets"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "UUID": UUID,
            "name": name]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["UUID"] { UUID = dbv.value() }
        if let dbv = row["name"] { name = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    init (UUID: String? = nil, name: String? = nil) {
        self.UUID = UUID
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE pets (" +
                "UUID TEXT NOT NULL PRIMARY KEY, " +
                "name TEXT NOT NULL" +
            ")")
    }
}

class PrimaryKeySingleTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPet", Pet.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(name: "Bobby")
                XCTAssertTrue(record.UUID == nil)
                do {
                    try record.insert(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                do {
                    try record.insert(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                record.name = "Carl"
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                try record.delete(db)
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(name: "Bobby")
                XCTAssertTrue(record.UUID == nil)
                do {
                    try record.save(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                record.name = "Carl"
                try record.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                var deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record1.insert(db)
                let record2 = Pet(UUID: "CainUUID", name: "Cain")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(Pet.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(Pet.fetch(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set([record1.UUID, record2.UUID]))
                }
                
                do {
                    let fetchedRecords = Array(Pet.fetch(db, keys: [["UUID": record1.UUID], ["UUID": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record1.insert(db)
                let record2 = Pet(UUID: "CainUUID", name: "Cain")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Pet.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Pet.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set([record1.UUID, record2.UUID]))
                }
                
                do {
                    let fetchedRecords = Pet.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                
                let fetchedRecord = Pet.fetchOne(db, key: ["UUID": record.UUID])!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                XCTAssertTrue(fetchedRecord.name == record.name)
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record1.insert(db)
                let record2 = Pet(UUID: "CainUUID", name: "Cain")
                try record2.insert(db)
                
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = Array(Pet.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = Array(Pet.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record1.insert(db)
                let record2 = Pet(UUID: "CainUUID", name: "Cain")
                try record2.insert(db)
                
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = Pet.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = Pet.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                
                do {
                    let id: String? = nil
                    let fetchedRecord = Pet.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = Pet.fetchOne(db, key: record.UUID)!
                    XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                    XCTAssertTrue(fetchedRecord.name == record.name)
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            XCTAssertFalse(record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Pet(UUID: "BobbyUUID", name: "Bobby")
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
}
