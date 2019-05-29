import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Person has a RowID primary key, and a overriden insert() method.
private class Person : Record {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: Date!
    
    init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: Date? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE persons (
                creationDate TEXT NOT NULL,
                name TEXT NOT NULL,
                age INT)
            """)
    }
    
    // Record
    
    override static var databaseSelection: [SQLSelectable] {
        return [AllColumns(), Column.rowID]
    }
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row[Column.rowID]
        age = row["age"]
        name = row["name"]
        creationDate = row["creationDate"]
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container[Column.rowID] = id
        container["name"] = name
        container["age"] = age
        container["creationDate"] = creationDate
    }
    
    override func insert(_ db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = Date()
        }
        
        try super.insert(db)
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

class RecordPrimaryKeyHiddenRowIDTests : GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            XCTAssertTrue(record.id == nil)
            try record.insert(db)
            XCTAssertTrue(record.id != nil)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        let record = Person(name: "Arthur")
        try dbQueue.inTransaction { db in
            XCTAssertTrue(record.id == nil)
            try record.insert(db)
            XCTAssertTrue(record.id != nil)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
            return .rollback
        }
        // This is debatable, actually.
        XCTAssertTrue(record.id != nil)
    }

    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: 123456, name: "Arthur")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        let record = Person(id: 123456, name: "Arthur")
        try dbQueue.inTransaction { db in
            try record.insert(db)
            XCTAssertEqual(record.id!, 123456)
            return .rollback
        }
        XCTAssertEqual(record.id!, 123456)
    }

    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
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
            let record = Person(name: "Arthur")
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Update

    func testUpdateWithNilPrimaryKeyThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: nil, name: "Arthur")
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "persons")
                XCTAssertEqual(key, ["rowid": .null])
            }
        }
    }

    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: 123456, name: "Arthur")
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "persons")
                XCTAssertEqual(key, ["rowid": record.id.databaseValue])
            }
        }
    }

    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur", age: 41)
            try record.insert(db)
            record.age = record.age! + 1
            try record.update(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "persons")
                XCTAssertEqual(key, ["rowid": record.id.databaseValue])
            }
        }
    }


    // MARK: - Save

    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            XCTAssertTrue(record.id == nil)
            try record.save(db)
            XCTAssertTrue(record.id != nil)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: 123456, name: "Arthur")
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }


    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur", age: 41)
            try record.insert(db)
            try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have thrown a database error for duplicated key.
            record.age = record.age! + 1
            try record.save(db)   // Actual update
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT *, rowid FROM persons WHERE rowid = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Delete

    func testDeleteWithNilPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: nil, name: "Arthur")
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: 123456, name: "Arthur")
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM persons WHERE rowid = ?", arguments: [record.id])
            XCTAssertTrue(row == nil)
        }
    }

    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
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
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let cursor = try Person.fetchCursor(db, keys: [])
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Person.fetchCursor(db, keys: [["rowid": record1.id], ["rowid": record2.id]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Person.fetchCursor(db, keys: [["rowid": record1.id], ["rowid": nil]])
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id!, record1.id!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Person.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Person.fetchAll(db, keys: [["rowid": record1.id], ["rowid": record2.id]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try Person.fetchAll(db, keys: [["rowid": record1.id], ["rowid": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }

    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            
            let fetchedRecord = try Person.fetchOne(db, key: ["rowid": record.id])!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertTrue(fetchedRecord.name == record.name)
            XCTAssertTrue(fetchedRecord.age == record.age)
            XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"persons\" WHERE \"rowid\" = \(record.id!)")
        }
    }

    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let cursor = try Person.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Person.filter(keys: [["rowid": record1.id], ["rowid": record2.id]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Person.filter(keys: [["rowid": record1.id], ["rowid": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.id!, record1.id!)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Person.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Person.filter(keys: [["rowid": record1.id], ["rowid": record2.id]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
            }
            
            do {
                let fetchedRecords = try Person.filter(keys: [["rowid": record1.id], ["rowid": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            
            let fetchedRecord = try Person.filter(key: ["rowid": record.id]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.id == record.id)
            XCTAssertTrue(fetchedRecord.name == record.name)
            XCTAssertTrue(fetchedRecord.age == record.age)
            XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"persons\" WHERE \"rowid\" = \(record.id!)")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = Person.orderByPrimaryKey()
            let sqlRequest = try SQLRequest(db, request: request)
            XCTAssertEqual(sqlRequest.sql, "SELECT *, \"rowid\" FROM \"persons\" ORDER BY \"rowid\"")
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let cursor = try Person.fetchCursor(db, keys: ids)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let cursor = try Person.fetchCursor(db, keys: ids)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try Person.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try Person.fetchAll(db, keys: ids)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
        }
    }

    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try Person.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Person.fetchOne(db, key: record.id)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"persons\" WHERE \"rowid\" = \(record.id!)")
            }
        }
    }

    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let cursor = try Person.filter(keys: ids).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let cursor = try Person.filter(keys: ids).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Person(name: "Arthur")
            try record1.insert(db)
            let record2 = Person(name: "Barbara")
            try record2.insert(db)
            
            do {
                let ids: [Int64] = []
                let fetchedRecords = try Person.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let ids = [record1.id!, record2.id!]
                let fetchedRecords = try Person.filter(keys: ids).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            
            do {
                let id: Int64? = nil
                let fetchedRecord = try Person.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Person.filter(key: record.id).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertEqual(lastSQLQuery, "SELECT *, \"rowid\" FROM \"persons\" WHERE \"rowid\" = \(record.id!)")
            }
        }
    }


    // MARK: - Exists

    func testExistsWithNilPrimaryKeyReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: nil, name: "Arthur")
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(id: 123456, name: "Arthur")
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }

    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur")
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }


    // MARK: - RowID
    
    func testRowIdIsSelectedByDefault() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let record = Person(name: "Arthur")
                try record.insert(db)
            }
            
            let records = try Person.fetchCursor(db)
            while let record = try records.next() {
                XCTAssert(record.id != nil)
            }
            
            XCTAssertTrue(try Person.fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.fetchOne(db, key: 1)!.id != nil)
            XCTAssertTrue(try Person.fetchOne(db, key: ["rowid": 1])!.id != nil)
            XCTAssertTrue(try Person.fetchAll(db).first!.id != nil)
            XCTAssertTrue(try Person.fetchAll(db, keys: [1]).first!.id != nil)
            XCTAssertTrue(try Person.fetchAll(db, keys: [["rowid": 1]]).first!.id != nil)
            XCTAssertTrue(try Person.all().fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.filter(Column.rowID == 1).fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.filter(sql: "rowid = 1").fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.order(Column.rowID).fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.order(sql: "rowid").fetchOne(db)!.id != nil)
            XCTAssertTrue(try Person.limit(1).fetchOne(db)!.id != nil)
        }
    }


    // MARK: - FetchedRecordsController

    func testFetchedRecordsController() throws {
        let dbQueue = try makeDatabaseQueue()
        let person = Person(name: "Arthur")
        try dbQueue.inDatabase { db in
            try person.insert(db)
        }
        
        let expectation = self.expectation(description: "expectation")
        let controller =
            try FetchedRecordsController<Person>(dbQueue, request: Person.all())
        var update = false
        controller.trackChanges(
            onChange: { (_, _, change) in if case .update = change { update = true /* identification by hidden rowid primary key has succeeded */ } },
            didChange: { _ in expectation.fulfill()
        })
        try controller.performFetch()
        try dbQueue.inDatabase { db in
            person.name = "Barbara"
            try person.update(db)
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        XCTAssertTrue(update)
    }
}
