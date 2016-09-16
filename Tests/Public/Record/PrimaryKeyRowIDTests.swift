import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT NOT NULL, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        age = row.value(named: "age")
        name = row.value(named: "name")
        creationDate = row.value(named: "creationDate")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationDate": creationDate,
        ]
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

class PrimaryKeyRowIDTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                XCTAssertTrue(record.id == nil)
                try record.insert(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
    
    func testRollbackedInsertWithNilPrimaryKeyDoesNotResetPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let record = Person(name: "Arthur")
            try dbQueue.inTransaction { db in
                XCTAssertTrue(record.id == nil)
                try record.insert(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
                for (key, value) in record.persistentDictionary {
                if let dbv: DatabaseValue = row.value(named: key) {
                    XCTAssertEqual(dbv, value?.databaseValue ?? .null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
                return .rollback
            }
            // This is debatable, actually.
            XCTAssertTrue(record.id != nil)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: 123456, name: "Arthur")
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
    
    func testRollbackedInsertWithNotNilPrimaryKeyDoeNotResetPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let record = Person(id: 123456, name: "Arthur")
            try dbQueue.inTransaction { db in
                try record.insert(db)
                XCTAssertEqual(record.id!, 123456)
                return .rollback
            }
            XCTAssertEqual(record.id!, 123456)
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
    
    func testUpdateWithNilPrimaryKeyThrowsRecordNotFound() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: nil, name: "Arthur")
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.recordNotFound")
                } catch PersistenceError.recordNotFound {
                    // Expected PersistenceError.recordNotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: 123456, name: "Arthur")
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
                let record = Person(name: "Arthur", age: 41)
                try record.insert(db)
                record.age = record.age! + 1
                try record.update(db)

                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
                let record = Person(name: "Arthur")
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
    
    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                XCTAssertTrue(record.id == nil)
                try record.save(db)
                XCTAssertTrue(record.id != nil)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: 123456, name: "Arthur")
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
                let record = Person(name: "Arthur", age: 41)
                try record.insert(db)
                try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                record.age = record.age! + 1
                try record.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
                let record = Person(name: "Arthur")
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])!
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
    
    func testDeleteWithNilPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: nil, name: "Arthur")
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(id: 123456, name: "Arthur")
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [record.id])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
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
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Person(name: "Arthur")
                try record1.insert(db)
                let record2 = Person(name: "Barbara")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(Person.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(Person.fetch(db, keys: [["id": record1.id], ["id": record2.id]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                }
                
                do {
                    let fetchedRecords = Array(Person.fetch(db, keys: [["id": record1.id], ["id": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Person(name: "Arthur")
                try record1.insert(db)
                let record2 = Person(name: "Barbara")
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Person.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Person.fetchAll(db, keys: [["id": record1.id], ["id": record2.id]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set([record1.id, record2.id]))
                }
                
                do {
                    let fetchedRecords = Person.fetchAll(db, keys: [["id": record1.id], ["id": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.id, record1.id!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                
                let fetchedRecord = Person.fetchOne(db, key: ["id": record.id])!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Person(name: "Arthur")
                try record1.insert(db)
                let record2 = Person(name: "Barbara")
                try record2.insert(db)
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Array(Person.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = Array(Person.fetch(db, keys: ids))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Person(name: "Arthur")
                try record1.insert(db)
                let record2 = Person(name: "Barbara")
                try record2.insert(db)
                
                do {
                    let ids: [Int64] = []
                    let fetchedRecords = Person.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let ids = [record1.id!, record2.id!]
                    let fetchedRecords = Person.fetchAll(db, keys: ids)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.id }), Set(ids))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                
                do {
                    let id: Int64? = nil
                    let fetchedRecord = Person.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = Person.fetchOne(db, key: record.id)!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertTrue(fetchedRecord.name == record.name)
                    XCTAssertTrue(fetchedRecord.age == record.age)
                    XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNilPrimaryKeyReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Person(id: nil, name: "Arthur")
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Person(id: 123456, name: "Arthur")
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur")
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
}
