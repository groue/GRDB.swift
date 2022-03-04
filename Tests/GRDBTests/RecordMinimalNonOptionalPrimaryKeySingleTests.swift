import XCTest
import GRDB

// MinimalNonOptionalPrimaryKeySingle is the most tiny class with a Single row
// primary key (with non-optional primary key property) which supports read and
// write operations of Record.
private class MinimalNonOptionalPrimaryKeySingle: Record, Hashable {
    /// Test non-optional ID type
    var id: String
    
    init(id: String) {
        self.id = id
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: "CREATE TABLE minimalSingles (id TEXT NOT NULL PRIMARY KEY)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        "minimalSingles"
    }
    
    required init(row: Row) throws {
        id = try row["id"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    static func == (lhs: MinimalNonOptionalPrimaryKeySingle, rhs: MinimalNonOptionalPrimaryKeySingle) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *)
extension MinimalNonOptionalPrimaryKeySingle: Identifiable { }

class RecordMinimalNonOptionalPrimaryKeySingleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMinimalNonOptionalPrimaryKeySingle", migrate: MinimalNonOptionalPrimaryKeySingle.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
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
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalSingles")
                XCTAssertEqual(key, ["id": "theUUID".databaseValue])
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            try record.update(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalSingles")
                XCTAssertEqual(key, ["id": "theUUID".databaseValue])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalSingles WHERE id = ?", arguments: [record.id])
            XCTAssertTrue(row == nil)
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
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
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, keys: [])
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, keys: [["id": record1.id], ["id": record2.id]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, keys: [["id": record1.id], ["id": nil]])
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id, record1.id)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, keys: [["id": record1.id], ["id": record2.id]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, keys: [["id": record1.id], ["id": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id)
            }
        }
    }
    
    func testFetchSetWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, keys: [["id": record1.id], ["id": record2.id]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, keys: [["id": record1.id], ["id": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id)
            }
        }
    }
    
    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            
            let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.fetchOne(db, key: ["id": record.id])!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
        }
    }
    
    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id, record1.id)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id)
            }
        }
    }
    
    func testFetchSetWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: []).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: [["id": record1.id], ["id": nil]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            
            let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.filter(key: ["id": record.id]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = MinimalNonOptionalPrimaryKeySingle.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"minimalSingles\" ORDER BY \"id\"")
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, keys: ids)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id, record2.id]
                let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, keys: ids)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, ids: ids)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let cursor = try MinimalNonOptionalPrimaryKeySingle.fetchCursor(db, ids: ids)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id, record2.id]
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchAll(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id, record2.id]
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.fetchSet(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.fetchOne(db, key: record.id)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.fetchOne(db, id: record.id)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
                }
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id, record2.id]
                let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchCursor(db)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let cursor = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchCursor(db)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id, record2.id]
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID1")
            try record1.insert(db)
            let record2 = MinimalNonOptionalPrimaryKeySingle(id: "theUUID2")
            try record2.insert(db)
            
            do {
                let ids: [String] = []
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id, record2.id]
                let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(keys: ids).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let ids: [String] = []
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id, record2.id]
                    let fetchedRecords = try MinimalNonOptionalPrimaryKeySingle.filter(ids: ids).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.filter(key: record.id).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalNonOptionalPrimaryKeySingle.filter(id: record.id).fetchOne(db)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalSingles\" WHERE \"id\" = '\(record.id)'")
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
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
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
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
            let record = MinimalNonOptionalPrimaryKeySingle(id: "theUUID")
            try record.insert(db)
            let ids = try MinimalSingle.all().selectID().fetchAll(db)
            XCTAssertEqual(ids, ["theUUID"])
        }
    }
}
