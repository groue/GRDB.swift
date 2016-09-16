import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["email": email, "label": label]
    }
}

class PrimaryKeySingleWithReplaceConflictResolutionTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createEmail", migrate: Email.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                record.label = "Home"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowReplacesARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                record.label = "Home"
                try record.insert(db)
                record.label = "Work"
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                try record.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRecordNotFound() {
        assertNoError {
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
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
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
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
                let record = Email()
                record.email = "me@domain.com"
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM emails WHERE email = ?", arguments: [record.email])!
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
    
    func testDeleteWithNotNilPrimaryKeyThatDoesNotMatchAnyRowDoesNothing() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
    }
    
    
    // MARK: - Fetch With Key
    
    func testFetchWithKeys() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let record = Email()
                record.email = "me@domain.com"
                XCTAssertFalse(record.exists(db))
            }
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
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
            let dbQueue = try makeDatabaseQueue()
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
