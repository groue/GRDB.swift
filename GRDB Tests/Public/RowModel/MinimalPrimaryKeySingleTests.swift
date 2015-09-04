import XCTest
import GRDB

// MinimalRowID is the most tiny class with a Single row primary key which
// supports read and write operations of RowModel.
class MinimalSingle: RowModel {
    var UUID: String!
    
    override class var databaseTable: Table? {
        return Table(named: "minimalSingles", primaryKey: .RowID("UUID"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["UUID": UUID]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "UUID": UUID = dbv.value()
        default:     super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalSingles (UUID TEXT NOT NULL PRIMARY KEY)")
    }
}

class MinimalPrimaryKeySingleTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.RowDeleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.reload(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM minimalSingles WHERE UUID = ?", arguments: [rowModel.UUID])!
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
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
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                
                let fetchedRowModel = MinimalSingle.fetchOne(db, primaryKey: rowModel.UUID)!
                XCTAssertTrue(fetchedRowModel.UUID == rowModel.UUID)
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                
                let fetchedRowModel = MinimalSingle.fetchOne(db, key: ["UUID": rowModel.UUID])!
                XCTAssertTrue(fetchedRowModel.UUID == rowModel.UUID)
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let rowModel = MinimalSingle()
            rowModel.UUID = "theUUID"
            XCTAssertFalse(rowModel.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = MinimalSingle()
                rowModel.UUID = "theUUID"
                try rowModel.insert(db)
                try rowModel.delete(db)
                XCTAssertFalse(rowModel.exists(db))
            }
        }
    }
}
