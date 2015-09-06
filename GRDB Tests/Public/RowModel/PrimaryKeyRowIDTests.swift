import XCTest
import GRDB

// Person has a RowID primary key, and a overriden insert() method.
class Person: RowModel {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: NSDate!
    
    override class func databaseTableName() -> String? {
        return "persons"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationDate": creationDate,
        ]
    }
    
    override func updateFromRow(row: Row) {
        for (column, dbv) in row {
            switch column {
            case "id":           id = dbv.value()
            case "name":         name = dbv.value()
            case "age":          age = dbv.value()
            case "creationDate": creationDate = dbv.value()
            default: break
            }
        }
        super.updateFromRow(row) // Subclasses are required to call super.
    }
    
    init (id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: NSDate? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    override func insert(db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT NOT NULL, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
}

class PrimaryKeyRowIDTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.id != nil)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testInsertWithNotNilPrimaryKeyThatMatchesARowThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                do {
                    try rowModel.insert(db)
                    XCTFail("Expected DatabaseError")
                } catch is DatabaseError {
                    // Expected DatabaseError
                }
            }
        }
    }
    
    func testInsertAfterDeleteInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
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
    
    func testUpdateWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                do {
                    try rowModel.update(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    func testUpdateWithNotNilPrimaryKeyThatMatchesARowUpdatesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.update(db)

                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testUpdateAfterDeleteThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                do {
                    try rowModel.update(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyInsertsARowAndSetsPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                XCTAssertTrue(rowModel.id == nil)
                try rowModel.save(db)
                XCTAssertTrue(rowModel.id != nil)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
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
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                try rowModel.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                rowModel.age = rowModel.age! + 1
                try rowModel.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
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
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
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
                let rowModel = Person(id: 123456, name: "Arthur")
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.RowDeleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                var deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.RowDeleted)
                deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    
    // MARK: - Reload
    
    func testReloadWithNotNilPrimaryKeyThatDoesNotMatchAnyRowThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(id: 123456, name: "Arthur")
                do {
                    try rowModel.reload(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    func testReloadWithNotNilPrimaryKeyThatMatchesARowFetchesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.reload(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM persons WHERE id = ?", arguments: [rowModel.id])!
                for (key, value) in rowModel.storedDatabaseDictionary {
                    if let dbv = row[key] {
                        XCTAssertEqual(dbv, value?.databaseValue ?? .Null)
                    } else {
                        XCTFail("Missing column \(key) in fetched row")
                    }
                }
            }
        }
    }
    
    func testReloadAfterDeleteThrowsRowModelNotFound() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                do {
                    try rowModel.reload(db)
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                    // Expected RowModelError.RowModelNotFound
                }
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                
                let fetchedRowModel = Person.fetchOne(db, primaryKey: rowModel.id)!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                
                let fetchedRowModel = Person.fetchOne(db, key: ["name": rowModel.name])!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let rowModel = Person(id: 123456, name: "Arthur")
            XCTAssertFalse(rowModel.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                XCTAssertFalse(rowModel.exists(db))
            }
        }
    }
}
