import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// MinimalRowID is the most tiny class with a RowID primary key which supports
// read and write operations of Record.
class MinimalRowID : Record {
    var id: Int64!
    
    init(id: Int64? = nil) {
        self.id = id
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalRowIDs (id INTEGER PRIMARY KEY)")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "minimalRowIDs"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

class RecordMinimalPrimaryKeyRowIDTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
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
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch PersistenceError.recordNotFound {
                // Expected PersistenceError.recordNotFound
            }
        }
    }

    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.update(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
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
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch PersistenceError.recordNotFound {
                // Expected PersistenceError.recordNotFound
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            record.id = 123456
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = MinimalRowID()
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
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
            
            let row = try Row.fetchOne(db, "SELECT * FROM minimalRowIDs WHERE id = ?", arguments: [record.id])
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
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let cursor = try MinimalRowID.fetchCursor(db, keys: [["id": record1.id], ["id": record2.id]])!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try MinimalRowID.fetchCursor(db, keys: [["id": record1.id], ["id": nil]])!
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
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try MinimalRowID.fetchAll(db, keys: [["id": record1.id], ["id": nil]])
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
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let cursor = try MinimalRowID.fetchCursor(db, keys: ids)!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
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
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
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
}
