import XCTest
import GRDB

// MinimalSingle is the most tiny class with a Single row primary key which
// supports read and write operations of Record.
class MinimalSingle: Record, Hashable {
    var UUID: String?
    
    init(UUID: String? = nil) {
        self.UUID = UUID
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: "CREATE TABLE minimalSingles (UUID TEXT NOT NULL PRIMARY KEY)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        "minimalSingles"
    }
    
    required init(row: Row) throws {
        UUID = try row["UUID"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["UUID"] = UUID
    }
    
    static func == (lhs: MinimalSingle, rhs: MinimalSingle) -> Bool {
        lhs.UUID == rhs.UUID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(UUID)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension MinimalSingle: Identifiable {
    /// Test non-optional ID type
    var id: String { UUID! }
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalSingles")
                XCTAssertEqual(key, ["UUID": "theUUID".databaseValue])
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalSingles")
                XCTAssertEqual(key, ["UUID": "theUUID".databaseValue])
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [record.UUID])
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
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalSingle.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalSingle.fetchCursor(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
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
    
    func testFetchSetWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalSingle.fetchSet(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalSingle.fetchSet(db, keys: [["UUID": record1.UUID], ["UUID": record2.UUID]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try MinimalSingle.fetchSet(db, keys: [["UUID": record1.UUID], ["UUID": nil]])
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
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
        }
    }
    
    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let cursor = try MinimalSingle.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.UUID!, record1.UUID!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchSetWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalSingle()
            record1.UUID = "theUUID1"
            try record1.insert(db)
            let record2 = MinimalSingle()
            record2.UUID = "theUUID2"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: []).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": record2.UUID]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set([record1.UUID!, record2.UUID!]))
            }
            
            do {
                let fetchedRecords = try MinimalSingle.filter(keys: [["UUID": record1.UUID], ["UUID": nil]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.UUID, record1.UUID!)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            
            let fetchedRecord = try MinimalSingle.filter(key: ["UUID": record.UUID]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.UUID == record.UUID)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = MinimalSingle.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"minimalSingles\" ORDER BY \"UUID\"")
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
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try MinimalSingle.fetchCursor(db, keys: UUIDs)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let cursor = try MinimalSingle.fetchCursor(db, ids: UUIDs)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let cursor = try MinimalSingle.fetchCursor(db, ids: UUIDs)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
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
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = try MinimalSingle.fetchAll(db, ids: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = try MinimalSingle.fetchAll(db, ids: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
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
                let fetchedRecords = try MinimalSingle.fetchSet(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try MinimalSingle.fetchSet(db, keys: UUIDs)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = try MinimalSingle.fetchSet(db, ids: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = try MinimalSingle.fetchSet(db, ids: UUIDs)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
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
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalSingle.fetchOne(db, id: record.UUID!)!
                    XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
                }
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
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
                let cursor = try MinimalSingle.filter(keys: UUIDs).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let cursor = try MinimalSingle.filter(keys: UUIDs).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let cursor = try MinimalSingle.filter(ids: UUIDs).fetchCursor(db)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let cursor = try MinimalSingle.filter(ids: UUIDs).fetchCursor(db)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try MinimalSingle.filter(keys: UUIDs).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try MinimalSingle.filter(keys: UUIDs).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = try MinimalSingle.filter(ids: UUIDs).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = try MinimalSingle.filter(ids: UUIDs).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try MinimalSingle.filter(keys: UUIDs).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let UUIDs = [record1.UUID!, record2.UUID!]
                let fetchedRecords = try MinimalSingle.filter(keys: UUIDs).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let UUIDs: [String] = []
                    let fetchedRecords = try MinimalSingle.filter(ids: UUIDs).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let UUIDs = [record1.UUID!, record2.UUID!]
                    let fetchedRecords = try MinimalSingle.filter(ids: UUIDs).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.UUID! }), Set(UUIDs))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try MinimalSingle.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalSingle.filter(key: record.UUID).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalSingle.filter(id: record.UUID!).fetchOne(db)!
                    XCTAssertTrue(fetchedRecord.UUID == record.UUID)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"UUID\" = '\(record.UUID!)'")
                }
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
    
    // MARK: Select ID
    
    func test_static_selectID() throws {
        guard #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) else {
            throw XCTSkip("Identifiable not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            let ids = try MinimalSingle.selectID().fetchAll(db)
            XCTAssertEqual(ids, ["theUUID"])
        }
    }
    
    func test_request_selectID() throws {
        guard #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) else {
            throw XCTSkip("Identifiable not available")
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalSingle()
            record.UUID = "theUUID"
            try record.insert(db)
            let ids = try MinimalSingle.all().selectID().fetchAll(db)
            XCTAssertEqual(ids, ["theUUID"])
        }
    }
}
