import XCTest
import GRDB

// Pet has a non-RowID primary key.
class Pet: RowModel {
    var UUID: String!
    var name: String!
    
    override class var databaseTable: Table? {
        return Table(named: "pets", primaryKey: .Column("UUID"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "UUID": UUID,
            "name": name]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "UUID":        UUID = dbv.value()
        case "name":        name = dbv.value()
        default:            super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    init (UUID: String? = nil, name: String? = nil) {
        self.UUID = UUID
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE pets (" +
                "UUID TEXT NOT NULL PRIMARY KEY, " +
                "name TEXT NOT NULL" +
            ")")
    }
}

class PrimaryKeySingleTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(name: "Bobby")
                XCTAssertTrue(rowModel.UUID == nil)
                do {
                    try rowModel.insert(db)
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                rowModel.name = "Carl"
                try rowModel.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
    
    func testSaveWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(name: "Bobby")
                XCTAssertTrue(rowModel.UUID == nil)
                do {
                    try rowModel.save(db)
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                try rowModel.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                rowModel.name = "Carl"
                try rowModel.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.RowDeleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                rowModel.name = "Carl"
                try rowModel.reload(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM pets WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
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
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                
                let fetchedRowModel = Pet.fetchOne(db, primaryKey: rowModel.UUID)!
                XCTAssertTrue(fetchedRowModel.UUID == rowModel.UUID)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                
                let fetchedRowModel = Pet.fetchOne(db, key: ["name": rowModel.name])!
                XCTAssertTrue(fetchedRowModel.UUID == rowModel.UUID)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
            XCTAssertFalse(rowModel.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Pet(UUID: "BobbyUUID", name: "Bobby")
                try rowModel.insert(db)
                try rowModel.delete(db)
                XCTAssertFalse(rowModel.exists(db))
            }
        }
    }
}
