import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["UUID": UUID]
    }
}

class MinimalPrimaryKeySingleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMinimalSingle", migrate: MinimalSingle.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
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
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                    if let dbv: DatabaseValue = row.value(named: key) {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() {
        assertNoError {
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
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                if let dbv: DatabaseValue = row.value(named: key) {
                    XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                if let dbv: DatabaseValue = row.value(named: key) {
                    XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
                for (key, value) in record.persistentDictionary {
                if let dbv: DatabaseValue = row.value(named: key) {
                    XCTAssertEqual(dbv, value?.databaseValue ?? .null)
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
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
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
            let dbQueue = try makeDatabaseQueue()
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
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
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
            let dbQueue = try makeDatabaseQueue()
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
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = Array(MinimalSingle.fetch(db, keys: UUIDs))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
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
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = MinimalSingle.fetchAll(db, keys: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = MinimalSingle()
                record.UUID = "theUUID"
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
