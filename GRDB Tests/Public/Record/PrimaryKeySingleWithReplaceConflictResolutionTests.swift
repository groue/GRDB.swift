import XCTest
import GRDB

class Email : Record {
    var email: String!
    var label: String?
    
    override class func databaseTableName() -> String? {
        return "emails"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["email": email, "label": label]
    }
    
    override func updateFromRow(row: Row) {
        if let dbv = row["email"] { email = dbv.value() }
        if let dbv = row["label"] { label = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE emails (" +
                "email TEXT NOT NULL PRIMARY KEY ON CONFLICT REPLACE, " +
                "label TEXT " +
            ")")
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
                    XCTFail("Expected RecordError.RecordNotFound")
                } catch RecordError.RecordNotFound {
                    // Expected RecordError.RecordNotFound
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
                    XCTFail("Expected RecordError.RecordNotFound")
                } catch RecordError.RecordNotFound {
                    // Expected RecordError.RecordNotFound
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
                let deletionResult = try record.delete(db)
                XCTAssertEqual(deletionResult, Record.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                let deletionResult = try record.delete(db)
                XCTAssertEqual(deletionResult, Record.DeletionResult.RowDeleted)
                
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
                var deletionResult = try record.delete(db)
                XCTAssertEqual(deletionResult, Record.DeletionResult.RowDeleted)
                deletionResult = try record.delete(db)
                XCTAssertEqual(deletionResult, Record.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    
    // MARK: - Reload
    
    func testReloadWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                do {
                    try record.reload(db)
                    XCTFail("Expected RecordError.RecordNotFound")
                } catch RecordError.RecordNotFound {
                    // Expected RecordError.RecordNotFound
                }
            }
        }
    }
    
    func testReloadWithNotNilPrimaryKeyThatMatchesARowFetchesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.reload(db)
                
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
    
    func testReloadAfterDeleteThrowsRecordNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                do {
                    try record.reload(db)
                    XCTFail("Expected RecordError.RecordNotFound")
                } catch RecordError.RecordNotFound {
                    // Expected RecordError.RecordNotFound
                }
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                
                let fetchedRecord = Email.fetchOne(db, primaryKey: record.email)!
                XCTAssertTrue(fetchedRecord.email == record.email)
            }
        }
    }
    
    func testSelectWithKey() {
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
