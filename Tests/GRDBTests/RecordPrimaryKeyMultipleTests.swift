import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    
    override func encode(to container: inout PersistenceContainer) {
        container["personName"] = personName
        container["countryName"] = countryName
        container["native"] = native
    }
}


class RecordPrimaryKeyMultipleTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createCitizenship", migrate: Citizenship.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() throws {
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

    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }

    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() throws {
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

    func testInsertAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Update

    func testUpdateWithNilPrimaryKeyThrowsRecordNotFound() throws {
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

    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
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

    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            record.native = false
            try record.update(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }

    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
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


    // MARK: - Save

    func testSaveWithNilPrimaryKeyThrowsDatabaseError() throws {
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

    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            try record.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
            record.native = false
            try record.save(db)   // Actual update
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Delete

    func testDeleteWithNilPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: nil, countryName: nil, native: true)
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [record.personName, record.countryName])
            XCTAssertTrue(row == nil)
        }
    }

    func testDeleteAfterDeleteDoesNothing() throws {
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


    // MARK: - Fetch With Key
    
    func testFetchCursorWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record1.insert(db)
            let record2 = Citizenship(personName: "Barbara", countryName: "France", native: false)
            try record2.insert(db)
            
            do {
                let cursor = try Citizenship.fetchCursor(db, keys: [])
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let cursor = try Citizenship.fetchCursor(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": record2.personName, "countryName": record2.countryName]])!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.personName }), Set([record1.personName, record2.personName]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Citizenship.fetchCursor(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": nil, "countryName": nil]])!
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.personName, record1.personName)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record1.insert(db)
            let record2 = Citizenship(personName: "Barbara", countryName: "France", native: false)
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Citizenship.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Citizenship.fetchAll(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": record2.personName, "countryName": record2.countryName]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.personName }), Set([record1.personName, record2.personName]))
            }
            
            do {
                let fetchedRecords = try Citizenship.fetchAll(db, keys: [["personName": record1.personName, "countryName": record1.countryName], ["personName": nil, "countryName": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.personName, record1.personName!)
            }
        }
    }

    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            
            let fetchedRecord = try Citizenship.fetchOne(db, key: ["personName": record.personName, "countryName": record.countryName])!
            XCTAssertTrue(fetchedRecord.personName == record.personName)
            XCTAssertTrue(fetchedRecord.countryName == record.countryName)
            XCTAssertTrue(fetchedRecord.native == record.native)
        }
    }


    // MARK: - Exists

    func testExistsWithNilPrimaryKeyReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: nil, countryName: nil, native: true)
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }

    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Citizenship(personName: "Arthur", countryName: "France", native: true)
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }
}
