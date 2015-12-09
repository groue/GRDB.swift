import XCTest
import GRDB

// MinimalSingle is the most tiny class with a Single row primary key which
// supports read and write operations of Record.
class MinimalSingle: Record {
    var UUID: String!
    
    override class func databaseTableName() -> String? {
        return "minimalSingles"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["UUID": UUID]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["UUID"] { UUID = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalSingles (UUID TEXT NOT NULL PRIMARY KEY)")
    }
}

class MinimalPrimaryKeySingleTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMinimalSingle", MinimalSingle.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
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
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
                let record = MinimalSingle()
                record.UUID = "theUUID"
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
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
    }
    
    
    // MARK: - Reload
    
    func testReloadWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                do {
                    try record.reload(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    func testReloadWithNotNilPrimaryKeyThatMatchesARowFetchesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.reload(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
    
    func testReloadAfterDeleteThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                do {
                    try record.reload(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = MinimalSingle()
                record1.UUID = "theUUID1"
                try record1.insert(db)
                let record2 = MinimalSingle()
                record2.UUID = "theUUID2"
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set([record1.UUID, record2.UUID]))
                }
                
                do {
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: [["UUID": record1.UUID], ["UUID": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = MinimalSingle()
                record1.UUID = "theUUID1"
                try record1.insert(db)
                let record2 = MinimalSingle()
                record2.UUID = "theUUID2"
                try record2.insert(db)
                
                do {
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set([record1.UUID, record2.UUID]))
                }
                
                do {
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                
                let fetchedRecord = MinimalSingle.fetchOne(db, key: ["UUID": record.UUID])!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = MinimalSingle()
                record1.UUID = "theUUID1"
                try record1.insert(db)
                let record2 = MinimalSingle()
                record2.UUID = "theUUID2"
                try record2.insert(db)
                
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = MinimalSingle()
                record1.UUID = "theUUID1"
                try record1.insert(db)
                let record2 = MinimalSingle()
                record2.UUID = "theUUID2"
                try record2.insert(db)
                
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                
                do {
                    let id: String? = nil
                    let fetchedRecord = MinimalSingle.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = MinimalSingle.fetchOne(db, key: record.UUID)!
                    XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            XCTAssertFalse(record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
}
