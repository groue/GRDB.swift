import XCTest
import GRDB

class Email : Record, Hashable {
    var email: String!
    var label: String?
    
    init(email: String? = nil, label: String? = nil) {
        self.email = email
        self.label = label
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE emails (
                email TEXT NOT NULL PRIMARY KEY ON CONFLICT REPLACE,
                label TEXT)
            """)
    }
    
    // Record
    
    override class var databaseTableName: String {
        "emails"
    }
    
    required init(row: Row) throws {
        email = try row["email"]
        label = try row["label"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["email"] = email
        container["label"] = label
    }
    
    static func == (lhs: Email, rhs: Email) -> Bool {
        lhs.label == rhs.label && lhs.email == rhs.email
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
        hasher.combine(email)
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "emails")
                XCTAssertEqual(key, ["email": record.email.databaseValue])
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "emails")
                XCTAssertEqual(key, ["email": record.email.databaseValue])
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM emails WHERE email = ?", arguments: [record.email])
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
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Email.fetchCursor(db, keys: [["email": record1.email], ["email": record2.email]])
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Email.fetchCursor(db, keys: [["email": record1.email], ["email": nil]])
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
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
            }
            
            do {
                let fetchedRecords = try Email.fetchAll(db, keys: [["email": record1.email], ["email": nil]])
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
            }
        }
    }
    
    func testFetchSetWithKeys() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Email.fetchSet(db, keys: [])
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Email.fetchSet(db, keys: [["email": record1.email], ["email": record2.email]])
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
            }
            
            do {
                let fetchedRecords = try Email.fetchSet(db, keys: [["email": record1.email], ["email": nil]])
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
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"emails\" WHERE \"email\" = '\(record.email!)'")
        }
    }
    
    
    // MARK: - Fetch With Key Request
    
    func testFetchCursorWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let cursor = try Email.filter(keys: []).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let cursor = try Email.filter(keys: [["email": record1.email], ["email": record2.email]]).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
            
            do {
                let cursor = try Email.filter(keys: [["email": record1.email], ["email": nil]]).fetchCursor(db)
                let fetchedRecord = try cursor.next()!
                XCTAssertEqual(fetchedRecord.email, record1.email)
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Email.filter(keys: []).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Email.filter(keys: [["email": record1.email], ["email": record2.email]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
            }
            
            do {
                let fetchedRecords = try Email.filter(keys: [["email": record1.email], ["email": nil]]).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
            }
        }
    }
    
    func testFetchSetWithKeysRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record1 = Email()
            record1.email = "me@domain.com"
            try record1.insert(db)
            let record2 = Email()
            record2.email = "you@domain.com"
            try record2.insert(db)
            
            do {
                let fetchedRecords = try Email.filter(keys: []).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let fetchedRecords = try Email.filter(keys: [["email": record1.email], ["email": record2.email]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set([record1.email, record2.email]))
            }
            
            do {
                let fetchedRecords = try Email.filter(keys: [["email": record1.email], ["email": nil]]).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 1)
                XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
            }
        }
    }
    
    func testFetchOneWithKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            
            let fetchedRecord = try Email.filter(key: ["email": record.email]).fetchOne(db)!
            XCTAssertTrue(fetchedRecord.email == record.email)
            XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"emails\" WHERE \"email\" = '\(record.email!)'")
        }
    }
    
    
    // MARK: - Order By Primary Key
    
    func testOrderByPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = Email.orderByPrimaryKey()
            try assertEqualSQL(db, request, "SELECT * FROM \"emails\" ORDER BY \"email\"")
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
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let cursor = try Email.fetchCursor(db, keys: emails)
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
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set(emails))
            }
        }
    }
    
    func testFetchSetWithPrimaryKeys() throws {
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
                let fetchedRecords = try Email.fetchSet(db, keys: emails)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let fetchedRecords = try Email.fetchSet(db, keys: emails)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set(emails))
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
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"emails\" WHERE \"email\" = '\(record.email!)'")
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key Request
    
    func testFetchCursorWithPrimaryKeysRequest() throws {
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
                let cursor = try Email.filter(keys: emails).fetchCursor(db)
                try XCTAssertNil(cursor.next())
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let cursor = try Email.filter(keys: emails).fetchCursor(db)
                let fetchedRecords = try [cursor.next()!, cursor.next()!]
                XCTAssertEqual(Set(fetchedRecords.map { $0.email! }), Set(emails))
                XCTAssertTrue(try cursor.next() == nil) // end
            }
        }
    }
    
    func testFetchAllWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try Email.filter(keys: emails).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let fetchedRecords = try Email.filter(keys: emails).fetchAll(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set(emails))
            }
        }
    }
    
    func testFetchSetWithPrimaryKeysRequest() throws {
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
                let fetchedRecords = try Email.filter(keys: emails).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 0)
            }
            
            do {
                let emails = [record1.email!, record2.email!]
                let fetchedRecords = try Email.filter(keys: emails).fetchSet(db)
                XCTAssertEqual(fetchedRecords.count, 2)
                XCTAssertEqual(Set(fetchedRecords.map(\.email)), Set(emails))
            }
        }
    }
    
    func testFetchOneWithPrimaryKeyRequest() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            try record.insert(db)
            
            do {
                let id: String? = nil
                let fetchedRecord = try Email.filter(key: id).fetchOne(db)
                XCTAssertTrue(fetchedRecord == nil)
            }
            
            do {
                let fetchedRecord = try Email.filter(key: record.email).fetchOne(db)!
                XCTAssertTrue(fetchedRecord.email == record.email)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"emails\" WHERE \"email\" = '\(record.email!)'")
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
