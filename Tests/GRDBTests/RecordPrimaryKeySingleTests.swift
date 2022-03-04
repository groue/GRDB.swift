import XCTest
import GRDB

// Pet has a non-RowID primary key.
class Pet : Record, Hashable {
    var UUID: String?
    var name: String
    
    init(UUID: String? = nil, name: String) {
        self.UUID = UUID
        self.name = name
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE pets (
                UUID TEXT NOT NULL PRIMARY KEY,
                name TEXT NOT NULL)
            """)
    }
    
    // Record
    
    override class var databaseTableName: String {
        "pets"
    }
    
    required init(row: Row) throws {
        UUID = try row["UUID"]
        name = try row["name"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["UUID"] = UUID
        container["name"] = name
    }
    
    static func == (lhs: Pet, rhs: Pet) -> Bool {
        lhs.UUID == rhs.UUID && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(UUID)
        hasher.combine(name)
    }
}

class RecordPrimaryKeySingleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPet", migrate: Pet.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
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
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
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
    
    func testInsertAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNilPrimaryKeyThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: nil, name: "Bobby")
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "pets")
                XCTAssertEqual(key, ["UUID": .null])
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "pets")
                XCTAssertEqual(key, ["UUID": "BobbyUUID".databaseValue])
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            record.name = "Carl"
            try record.update(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "pets")
                XCTAssertEqual(key, ["UUID": "BobbyUUID".databaseValue])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
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
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
            record.name = "Carl"
            try record.save(db)   // Actual update
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNilPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: nil, name: "Bobby")
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])
            XCTAssertTrue(row == nil)
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            var deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchCursorWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let cursor = try Pet.fetchCursor(db, keys: [])
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Pet.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Pet.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.UUID!, record1.UUID!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Pet.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Pet.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try Pet.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchSetWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Pet.fetchSet(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Pet.fetchSet(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try Pet.fetchSet(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            let fetchedRecord = try Pet.fetchOne(db, key: ["UUID": record.UUID])!
            XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            XCTAssertTrue(fetchedRecord.name == record.name)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"pets\" WHERE \"UUID\" = '\(record.UUID!)'")
        }
    }
    
    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let cursor = try Pet.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.UUID!, record1.UUID!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Pet.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchSetWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Pet.filter(keys: []).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try Pet.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            let fetchedRecord = try Pet.filter(key: ["UUID": record.UUID]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            XCTAssertTrue(fetchedRecord.name == record.name)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"pets\" WHERE \"UUID\" = '\(record.UUID!)'")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = Pet.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"pets\" ORDER BY \"UUID\"")
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let cursor = try Pet.fetchCursor(db, keys: UUIDs)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try Pet.fetchCursor(db, keys: UUIDs)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let fetchedRecords = try Pet.fetchAll(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try Pet.fetchAll(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let fetchedRecords = try Pet.fetchSet(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try Pet.fetchSet(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try Pet.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Pet.fetchOne(db, key: record.UUID)!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"pets\" WHERE \"UUID\" = '\(record.UUID!)'")
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let cursor = try Pet.filter(keys: UUIDs).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try Pet.filter(keys: UUIDs).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let fetchedRecords = try Pet.filter(keys: UUIDs).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try Pet.filter(keys: UUIDs).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record1.insert(db)
            let record2 = Pet(UUID: "CainUUID", name: "Cain")
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let fetchedRecords = try Pet.filter(keys: UUIDs).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try Pet.filter(keys: UUIDs).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try Pet.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Pet.filter(key: record.UUID).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"pets\" WHERE \"UUID\" = '\(record.UUID!)'")
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNilPrimaryKeyReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: nil, name: "Bobby")
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }
}
