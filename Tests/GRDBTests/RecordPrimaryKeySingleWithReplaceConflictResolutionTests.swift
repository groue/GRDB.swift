import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class Email : Record {
    var email: String!
    var label: String?
    
    init(email: String? = nil, label: String? = nil) {
        self.email = email
        self.label = label
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(
            "CREATE TABLE emails (" +
                "email TEXT NOT NULL PRIMARY KEY ON CONFLICT REPLACE, " +
                "label TEXT " +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "emails"
    }
    
    required init(row: Row) {
        email = row.value(named: "email")
        label = row.value(named: "label")
        super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["email"] = email
        container["label"] = label
    }
}

class RecordPrimaryKeySingleWithReplaceConflictResolutionTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createEmail", migrate: Email.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            XCTAssertTrue(record.email == nil)
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
            let record = Email()
            record.email = "me@domain.com"
            record.label = "Home"
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }

    func testInsertWithNotNilPrimaryKeyThatMatchesARowReplacesARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            record.label = "Home"
            try record.insert(db)
            record.label = "Work"
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }

    func testInsertAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            try record.delete(db)
            try record.insert(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Update

    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
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
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            try record.update(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }

    func testUpdateAfterDeleteThrowsRecordNotFound() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
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
            let record = Email()
            XCTAssertTrue(record.email == nil)
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
            let record = Email()
            record.email = "me@domain.com"
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSaveAfterDeleteInsertsARow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
            assert(record, isEncodedIn: row)
        }
    }


    // MARK: - Delete

    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            let deleted = try record.delete(db)
            XCTAssertFalse(deleted)
        }
    }

    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            let deleted = try record.delete(db)
            XCTAssertTrue(deleted)
            
            let row = try Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])
            XCTAssertTrue(row == nil)
        }
    }

    func testDeleteAfterDeleteDoesNothing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
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
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let cursor = try Email.fetchCursor(db, keys: [])
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let cursor = try Email.fetchCursor(db, keys: [["email": record1.email], ["email": record2.email]])!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set([record1.email, record2.email]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Email.fetchCursor(db, keys: [["email": record1.email], ["email": nil]])!
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.email, record1.email)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Email.fetchAll(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Email.fetchAll(db, keys: [["email": record1.email], ["email": record2.email]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set([record1.email, record2.email]))
            }
            
            do {
                let fetchedRecords = try Email.fetchAll(db, keys: [["email": record1.email], ["email": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
            }
        }
    }

    func testFetchOneWithKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            
            let fetchedRecord = try Email.fetchOne(db, key: ["email": record.email])!
            XCTAssertTrue(fetchedRecord.email == record.email)
        }
    }


    // MARK: - Fetch With Primary Key
    
    func testFetchCursorWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let emails: [String] = []
                let cursor = try Email.fetchCursor(db, keys: emails)
                XCTAssertTrue(cursor == nil)
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let cursor = try Email.fetchCursor(db, keys: emails)!
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.email! }), Set(emails))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }

    func testFetchAllWithPrimaryKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let emails: [String] = []
                let fetchedRecords = try Email.fetchAll(db, keys: emails)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let fetchedRecords = try Email.fetchAll(db, keys: emails)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set(emails))
            }
        }
    }

    func testFetchOneWithPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try Email.fetchOne(db, key: id)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Email.fetchOne(db, key: record.email)!
                XCTAssertTrue(fetchedRecord.email == record.email)
            }
        }
    }


    // MARK: - Exists

    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }

    func testExistsAfterDeleteReturnsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            try record.delete(db)
            XCTAssertFalse(try record.exists(db))
        }
    }
}
