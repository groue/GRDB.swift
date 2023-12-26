import XCTest
import GRDB

// MinimalRowID is the most tiny class with a RowID primary key which supports
// read and write operations of Record.
class MinimalRowID : Record, Hashable {
    /// Test optional ID type
    var id: Int64?
    
    init(id: Int64? = nil) {
        self.id = id
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: "CREATE TABLE minimalRowIDs (id INTEGER PRIMARY KEY)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        "minimalRowIDs"
    }
    
    required init(row: Row) throws {
        id = row["id"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
    }
    
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
    
    static func == (lhs: MinimalRowID, rhs: MinimalRowID) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *)
extension MinimalRowID: Identifiable { }

class RecordMinimalPrimaryKeyRowIDTests : GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMinimalRowID", migrate: MinimalRowID.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            XCTAssertTrue(record.id == nil)
            try record.insert(db)
            XCTAssertTrue(record.id != nil)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
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
            let record = MinimalRowID()
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            do {
                try record.update(db)
                XCTFail("Expected RecordError.recordNotFound")
            } catch let RecordError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected RecordError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalRowIDs")
                XCTAssertEqual(key, ["id": record.id!.databaseValue])
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.update(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected RecordError.recordNotFound")
            } catch let RecordError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected RecordError.recordNotFound
                XCTAssertEqual(databaseTableName, "minimalRowIDs")
                XCTAssertEqual(key, ["id": record.id!.databaseValue])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            XCTAssertTrue(record.id == nil)
            try record.save(db)
            XCTAssertTrue(record.id != nil)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            try assert(record, isEncodedIn: row)
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])
            XCTAssertTrue(row == nil)
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
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
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let cursor = try MinimalRowID.fetchCursor(db, keys: [])
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalRowID.fetchCursor(db, keys: [["id": record1.id], ["id": record2.id]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalRowID.fetchCursor(db, keys: [["id": record1.id], ["id": nil]])
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id!, record1.id!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: [["id": record1.id], ["id": record2.id]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: [["id": record1.id], ["id": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }
    
    func testFetchSetWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalRowID.fetchSet(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalRowID.fetchSet(db, keys: [["id": record1.id], ["id": record2.id]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalRowID.fetchSet(db, keys: [["id": record1.id], ["id": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }
    
    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            let fetchedRecord = try MinimalRowID.fetchOne(db, key: ["id": record.id])!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
        }
    }
    
    func testFindWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            let fetchedRecord = try MinimalRowID.find(db, key: ["id": record.id])
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
        }
    }

    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let cursor = try MinimalRowID.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try MinimalRowID.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalRowID.filter(keys: [["id": record1.id], ["id": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id!, record1.id!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: [["id": record1.id], ["id": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }
    
    func testFetchSetWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: []).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: [["id": record1.id], ["id": record2.id]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalRowID.filter(keys: [["id": record1.id], ["id": nil]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            let fetchedRecord = try MinimalRowID.filter(key: ["id": record.id]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = MinimalRowID.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"minimalRowIDs\" ORDER BY \"id\"")
        }
    }
    
    
    // MARK: - Stable order
    
    func testStableOrder() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = MinimalRowID.all().withStableOrder()
            try assertEqualSQL(db, request, "SELECT * FROM \"minimalRowIDs\" ORDER BY \"id\"")
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let cursor = try MinimalRowID.fetchCursor(db, keys: ids)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let cursor = try MinimalRowID.fetchCursor(db, keys: ids)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let cursor = try MinimalRowID.fetchCursor(db, ids: ids)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let cursor = try MinimalRowID.fetchCursor(db, ids: ids)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = try MinimalRowID.fetchAll(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = try MinimalRowID.fetchAll(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try MinimalRowID.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try MinimalRowID.fetchSet(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = try MinimalRowID.fetchSet(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = try MinimalRowID.fetchSet(db, ids: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try MinimalRowID.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalRowID.fetchOne(db, key: record.id)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalRowID.fetchOne(db, id: record.id!)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
                }
                do {
                    try XCTAssertNil(MinimalRowID.fetchOne(db, id: nil))
                }
            }
        }
    }
    
    func testFindWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            do {
                let id: Int64? = nil
                _ = try MinimalRowID.find(db, key: id)
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "minimalRowIDs", key: ["id": .null]) { }

            do {
                let fetchedRecord = try MinimalRowID.find(db, key: record.id)
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    _ = try MinimalRowID.find(db, id: -1)
                    XCTFail("Expected RecordError")
                } catch RecordError.recordNotFound(databaseTableName: "minimalRowIDs", key: ["id": (-1).databaseValue]) { }
                
                do {
                    let fetchedRecord = try MinimalRowID.find(db, id: record.id!)
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
                }
                do {
                    try XCTAssertNil(MinimalRowID.fetchOne(db, id: nil))
                }
            }
        }
    }

    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let cursor = try MinimalRowID.filter(keys: ids).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let cursor = try MinimalRowID.filter(keys: ids).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let cursor = try MinimalRowID.filter(ids: ids).fetchCursor(db)
                    try XCTAssertNil(cursor.next())
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let cursor = try MinimalRowID.filter(ids: ids).fetchCursor(db)
                    let fetchedRecords = try [cursor.next()!, cursor.next()!]
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                    XCTAssertTrue(try cursor.next() == nil) // end
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try MinimalRowID.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try MinimalRowID.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = try MinimalRowID.filter(ids: ids).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = try MinimalRowID.filter(ids: ids).fetchAll(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                }
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = MinimalRowID()
            try record1.insert(db)
            let record2 = MinimalRowID()
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try MinimalRowID.filter(keys: ids).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try MinimalRowID.filter(keys: ids).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = try MinimalRowID.filter(ids: ids).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = try MinimalRowID.filter(ids: ids).fetchSet(db)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map(\.id)), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try MinimalRowID.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try MinimalRowID.filter(key: record.id).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
            }
            
            if #available(iOS 13, macOS 10.15, tvOS 13, watchOS 6, *) {
                do {
                    let fetchedRecord = try MinimalRowID.filter(id: record.id!).fetchOne(db)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"minimalRowIDs\" WHERE \"id\" = \(record.id!)")
                }
                do {
                    try XCTAssertNil(MinimalRowID.filter(id: nil).fetchOne(db))
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    // MARK: Select PrimaryKey
    
    func test_static_selectPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            let ids: [Int64] = try MinimalRowID.selectPrimaryKey().fetchAll(db)
            XCTAssertEqual(ids, [1])
            let rows = try MinimalRowID.selectPrimaryKey(as: Row.self).fetchAll(db)
            XCTAssertEqual(rows, [["id": 1]])
        }
    }
    
    func test_request_selectPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            let ids: [Int64] = try MinimalRowID.all().selectPrimaryKey().fetchAll(db)
            XCTAssertEqual(ids, [1])
            let rows = try MinimalRowID.all().selectPrimaryKey(as: Row.self).fetchAll(db)
            XCTAssertEqual(rows, [["id": 1]])
        }
    }
}
