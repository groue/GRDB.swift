import XCTest
import GRDB

class Email : Record {
    var email: String!
    var label: String?
    
    required init(email: String? = nil, label: String? = nil) {
        self.email = email
        self.label = label
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE emails (" +
                "email TEXT NOT NULL PRIMARY KEY ON CONFLICT REPLACE, " +
                "label TEXT " +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "emails"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["email": email, "label": label]
    }
    
    override class func fromRow(row: Row) -> Self {
        return self.init(
            email: row.value(named: "email"),
            label: row.value(named: "label"))
    }
}

class PrimaryKeySingleWithReplaceConflictResolutionTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createEmail", Email.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                record.label = "Home"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowReplacesARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                record.label = "Home"
                try record.insert(db)
                record.label = "Work"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Update
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                do {
                    try record.update(db)
                    XCTFail("Expected PersistenceError.NotFound")
                } catch PersistenceError.NotFound {
                    // Expected PersistenceError.NotFound
                }
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
                for (key, value) in record.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    
    // MARK: - Delete
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                let deleted = try record.delete(db)
                XCTAssertFalse(deleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                let deleted = try record.delete(db)
                XCTAssertTrue(deleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
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
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Email()
                record1.email = "me@domain.com"
                try record1.insert(db)
                let record2 = Email()
                record2.email = "you@domain.com"
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Array(Email.fetch(db, keys: []))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Array(Email.fetch(db, keys: [["email": record1.email], ["email": record2.email]]))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set([record1.email, record2.email]))
                }
                
                do {
                    let fetchedRecords = Array(Email.fetch(db, keys: [["email": record1.email], ["email": nil]]))
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
                }
            }
        }
    }
    
    func testFetchAllWithKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Email()
                record1.email = "me@domain.com"
                try record1.insert(db)
                let record2 = Email()
                record2.email = "you@domain.com"
                try record2.insert(db)
                
                do {
                    let fetchedRecords = Email.fetchAll(db, keys: [])
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let fetchedRecords = Email.fetchAll(db, keys: [["email": record1.email], ["email": record2.email]])
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set([record1.email, record2.email]))
                }
                
                do {
                    let fetchedRecords = Email.fetchAll(db, keys: [["email": record1.email], ["email": nil]])
                    XCTAssertEqual(fetchedRecords.count, 1)
                    XCTAssertEqual(fetchedRecords.first!.email, record1.email!)
                }
            }
        }
    }
    
    func testFetchOneWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                
                let fetchedRecord = Email.fetchOne(db, key: ["email": record.email])!
                XCTAssertTrue(fetchedRecord.email == record.email)
            }
        }
    }
    
    
    // MARK: - Fetch With Primary Key
    
    func testFetchWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Email()
                record1.email = "me@domain.com"
                try record1.insert(db)
                let record2 = Email()
                record2.email = "you@domain.com"
                try record2.insert(db)
                
                do {
                    let emails: [String] = []
                    let fetchedRecords = Array(Email.fetch(db, keys: emails))
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let emails = [record1.email!, record2.email!]
                    let fetchedRecords = Array(Email.fetch(db, keys: emails))
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set(emails))
                }
            }
        }
    }
    
    func testFetchAllWithPrimaryKeys() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record1 = Email()
                record1.email = "me@domain.com"
                try record1.insert(db)
                let record2 = Email()
                record2.email = "you@domain.com"
                try record2.insert(db)
                
                do {
                    let emails: [String] = []
                    let fetchedRecords = Email.fetchAll(db, keys: emails)
                    XCTAssertEqual(fetchedRecords.count, 0)
                }
                
                do {
                    let emails = [record1.email!, record2.email!]
                    let fetchedRecords = Email.fetchAll(db, keys: emails)
                    XCTAssertEqual(fetchedRecords.count, 2)
                    XCTAssertEqual(Set(fetchedRecords.map { $0.email }), Set(emails))
                }
            }
        }
    }
    
    func testFetchOneWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                
                do {
                    let id: String? = nil
                    let fetchedRecord = Email.fetchOne(db, key: id)
                    XCTAssertTrue(fetchedRecord == nil)
                }
                
                do {
                    let fetchedRecord = Email.fetchOne(db, key: record.email)!
                    XCTAssertTrue(fetchedRecord.email == record.email)
                }
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let record = Email()
            record.email = "me@domain.com"
            XCTAssertFalse(record.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                XCTAssertTrue(record.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                XCTAssertFalse(record.exists(db))
            }
        }
    }
}
