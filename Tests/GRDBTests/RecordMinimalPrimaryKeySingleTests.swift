import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// MinimalSingle is the most tiny class with a Single row primary key which
// supports read and write operations of Record.
class MinimalSingle: Record {
    var UUID: String?
    
    init(UUID: String? = nil) {
        self.UUID = UUID
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalSingles (UUID TEXT NOT NULL PRIMARY KEY)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "minimalSingles"
    }
    
    required init(row: Row) {
        UUID = row.value(named: "UUID")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["UUID"] = UUID
    }
}

class RecordMinimalPrimaryKeySingleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMinimalSingle", migrate: MinimalSingle.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
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
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }

    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
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
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Update

    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
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
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            try record.update(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }

    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
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
            let record = MinimalSingle()
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
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Delete

    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])
            XCTAssertTrue(row == nil)
        }
    }

    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
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
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let cursor = try MinimalSingle.fetchCursor(db, keys: [])
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let cursor = try MinimalSingle.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalSingle.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": nil]])!
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.UUID!, record1.UUID!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalSingle.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalSingle.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try MinimalSingle.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }

    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            
            let fetchedRecord = try MinimalSingle.fetchOne(db, key: ["UUID": record.UUID])!
            XCTAssertTrue(fetchedRecord.UUID == record.UUID)
        }
    }


    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let cursor = try MinimalSingle.fetchCursor(db, keys: UUIDs)
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try MinimalSingle.fetchCursor(db, keys: UUIDs)!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let UUIDs: [String] = []
                let fetchedRecords = try MinimalSingle.fetchAll(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try MinimalSingle.fetchAll(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
        }
    }

    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try MinimalSingle.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalSingle.fetchOne(db, key: record.UUID)!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            }
        }
    }


    // MARK: - Exists

    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }

    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }
}
