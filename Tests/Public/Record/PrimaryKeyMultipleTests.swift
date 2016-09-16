import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Citizenship has a multiple-column primary key.
private class Citizenship : Record {
    var personName: String!
    var countryName: String!
    var native: Bool!
    
    init(personName: String? = nil, countryName: String? = nil, native: Bool? = nil) {
        self.personName = personName
        self.countryName = countryName
        self.native = native
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE citizenships (" +
                "personName TEXT NOT NULL, " +
                "countryName TEXT NOT NULL, " +
                "native BOOLEAN NOT NULL, " +
                "PRIMARY KEY (personName, countryName)" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "citizenships"
    }
    
    required init(row: Row) {
        personName = row.value(named: "personName")
        countryName = row.value(named: "countryName")
        native = row.value(named: "native")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "personName": personName,
            "countryName": countryName,
            "native": native]
    }
}


class PrimaryKeyMultipleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createCitizenship", migrate: Citizenship.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(native: true)
                XCTAssertTrue(record.personName == nil && record.countryName == nil)
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: nil, countryName: nil, native: true)
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                record.native = false
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let record = Citizenship(native: true)
                XCTAssertTrue(record.personName == nil && record.countryName == nil)
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                record.native = false
                try record.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
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
                let record = Citizenship(personName: nil, countryName: nil, native: true)
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let record1 = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record1.insert(db)
                let record2 = Citizenship(personName: "Barbara", countryName: "France", native: false)
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(Citizenship.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(Citizenship.fetch(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": record2.personName, "countryName": record2.countryName]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.personName }), Set([record1.personName, record2.personName]))
                }
                
                do {
                    let fetchedRecords = Array(Citizenship.fetch(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": nil, "countryName": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.personName, record1.personName!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record1 = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record1.insert(db)
                let record2 = Citizenship(personName: "Barbara", countryName: "France", native: false)
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Citizenship.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Citizenship.fetchAll(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": record2.personName, "countryName": record2.countryName]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.personName }), Set([record1.personName, record2.personName]))
                }
                
                do {
                    let fetchedRecords = Citizenship.fetchAll(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": nil, "countryName": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.personName, record1.personName!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                
                let fetchedRecord = Citizenship.fetchOne(db, key: ["personName": record.personName, "countryName": record.countryName])!
                XCTAssertTrue(fetchedRecord.personName == record.personName)
                XCTAssertTrue(fetchedRecord.countryName == record.countryName)
                XCTAssertTrue(fetchedRecord.native == record.native)
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNilPrimaryKeyReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Citizenship(personName: nil, countryName: nil, native: true)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
}
