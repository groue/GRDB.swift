import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Pet has a non-RowID primary key.
class Pet : Record {
    var UUID: String?
    var name: String
    
    init(UUID: String? = nil, name: String) {
        self.UUID = UUID
        self.name = name
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE pets (" +
                "UUID TEXT NOT NULL PRIMARY KEY, " +
                "name TEXT NOT NULL" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "pets"
    }
    
    required init(row: Row) {
        UUID = row.value(named: "UUID")
        name = row.value(named: "name")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["UUID"] = UUID
        container["name"] = name
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            } catch PersistenceError.recordNotFound {
                // Expected PersistenceError.recordNotFound
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
            } catch PersistenceError.recordNotFound {
                // Expected PersistenceError.recordNotFound
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            } catch PersistenceError.recordNotFound {
                // Expected PersistenceError.recordNotFound
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [record.UUID])
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
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let cursor = try Pet.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Pet.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": nil]])!
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

    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Pet(UUID: "BobbyUUID", name: "Bobby")
            try record.insert(db)
            
            let fetchedRecord = try Pet.fetchOne(db, key: ["UUID": record.UUID])!
            XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            XCTAssertTrue(fetchedRecord.name == record.name)
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
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try Pet.fetchCursor(db, keys: UUIDs)!
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
