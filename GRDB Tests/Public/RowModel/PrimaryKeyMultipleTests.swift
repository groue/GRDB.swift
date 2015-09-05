import XCTest
import GRDB

// Citizenship has a multiple-column primary key.
class Citizenship: RowModel {
    var personName: String!
    var countryName: String!
    var native: Bool!
    
    override class var databaseTableName: String? {
        return "citizenships"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "personName": personName,
            "countryName": countryName,
            "native": native]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "personName":  personName = dbv.value()
        case "countryName": countryName = dbv.value()
        case "native":      native = dbv.value()
        default:            super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    init (personName: String? = nil, countryName: String? = nil, native: Bool? = nil) {
        self.personName = personName
        self.countryName = countryName
        self.native = native
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE citizenships (" +
                "personName TEXT NOT NULL, " +
                "countryName TEXT NOT NULL, " +
                "native BOOLEAN NOT NULL, " +
                "PRIMARY KEY (personName, countryName)" +
            ")")
    }
}


class PrimaryKeyMultipleTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertWithNilPrimaryKeyThrowsDatabaseError() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(native: true)
                XCTAssertTrue(rowModel.personName == nil && rowModel.countryName == nil)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.insert(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                rowModel.native = false
                try rowModel.update(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let rowModel = Citizenship(native: true)
                XCTAssertTrue(rowModel.personName == nil && rowModel.countryName == nil)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                try rowModel.save(db)   // Test that useless update succeeds. It is a proof that save() has performed an UPDATE statement, and not an INSERT statement: INSERT would have throw a database error for duplicated key.
                rowModel.native = false
                try rowModel.save(db)   // Actual update
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.NoRowDeleted)
            }
        }
    }
    
    func testDeleteWithNotNilPrimaryKeyThatMatchesARowDeletesThatRow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                let deletionResult = try rowModel.delete(db)
                XCTAssertEqual(deletionResult, RowModel.DeletionResult.RowDeleted)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])
                XCTAssertTrue(row == nil)
            }
        }
    }
    
    func testDeleteAfterDeleteDoesNothing() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                rowModel.native = false
                try rowModel.reload(db)
                
                let row = Row.fetchOne(db, "SELECT * FROM citizenships WHERE personName = ? AND countryName = ?", arguments: [rowModel.personName, rowModel.countryName])!
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
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
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
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                
                let fetchedRowModel = Citizenship.fetchOne(db, key: ["personName": "Arthur", "countryName": "France"])!
                XCTAssertTrue(fetchedRowModel.personName == rowModel.personName)
                XCTAssertTrue(fetchedRowModel.countryName == rowModel.countryName)
                XCTAssertTrue(fetchedRowModel.native == rowModel.native)
            }
        }
    }
    
    
    // MARK: - Exists
    
    func testExistsWithNotNilPrimaryKeyThatDoesNotMatchAnyRowReturnsFalse() {
        dbQueue.inDatabase { db in
            let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
            XCTAssertFalse(rowModel.exists(db))
        }
    }
    
    func testExistsWithNotNilPrimaryKeyThatMatchesARowReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                XCTAssertTrue(rowModel.exists(db))
            }
        }
    }
    
    func testExistsAfterDeleteReturnsTrue() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Citizenship(personName: "Arthur", countryName: "France", native: true)
                try rowModel.insert(db)
                try rowModel.delete(db)
                XCTAssertFalse(rowModel.exists(db))
            }
        }
    }
}
