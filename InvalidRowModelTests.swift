import XCTest
import GRDB

class RowModelWithoutDatabaseTableName: RowModel { }

class RowModelWithInexistingDatabaseTable: RowModel {
    override static func databaseTableName() -> String? {
        return "foo"
    }
}

class RowModelWithEmptyStoredDatabaseDictionary : RowModel {
    override static func databaseTableName() -> String? {
        return "models"
    }
}

class RowModelWithNilPrimaryKey : RowModel {
    override static func databaseTableName() -> String? {
        return "models"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": nil]
    }
}

class RowModelForTableWithoutPrimaryKey : RowModel {
    override static func databaseTableName() -> String? {
        return "models"
    }

    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RowModelForTableWithMultipleColumnsPrimaryKey : RowModel {
    override static func databaseTableName() -> String? {
        return "models"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RowModelWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary : RowModel {
    override static func databaseTableName() -> String? {
        return "models"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class InvalidRowModelTests: GRDBTestCase {
    
    // =========================================================================
    // MARK: - RowModelWithoutDatabaseTableName
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeFetchedByID() {
//        dbQueue.inDatabase { db in
//            RowModelWithoutDatabaseTableName.fetchOne(db, primaryKey: 1)
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeFetchedByKey() {
//        dbQueue.inDatabase { db in
//            RowModelWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithoutDatabaseTableName().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithoutDatabaseTableNameCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithoutDatabaseTableName().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelWithInexistingDatabaseTable
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeFetchedByID() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithInexistingDatabaseTable.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeFetchedByKey() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithInexistingDatabaseTable.fetchOne(db, key: ["id": 1])
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithInexistingDatabaseTable().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithInexistingDatabaseTable().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithInexistingDatabaseTable().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithInexistingDatabaseTable().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RowModelWithInexistingDatabaseTable().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithInexistingDatabaseTableCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RowModelWithInexistingDatabaseTable().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelWithEmptyStoredDatabaseDictionary
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithEmptyStoredDatabaseDictionary().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithEmptyStoredDatabaseDictionary().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithEmptyStoredDatabaseDictionary().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithEmptyStoredDatabaseDictionary().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithEmptyStoredDatabaseDictionary().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithEmptyStoredDatabaseDictionaryCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                RowModelWithEmptyStoredDatabaseDictionary().exists(db)
//            }
//        }
//    }
    
    // =========================================================================
    // MARK: - RowModelWithNilPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRowModelWithNilPrimaryKeyCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithNilPrimaryKey().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithNilPrimaryKeyCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithNilPrimaryKey().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithNilPrimaryKeyCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                try RowModelWithNilPrimaryKey().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelWithNilPrimaryKeyCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY)")
//                RowModelWithNilPrimaryKey().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelForTableWithoutPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithoutPrimaryKeyCanNotBeFetchedByID() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (name TEXT)")
//                RowModelForTableWithoutPrimaryKey.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithoutPrimaryKeyCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (name TEXT)")
//                try RowModelForTableWithoutPrimaryKey().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithoutPrimaryKeyCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (name TEXT)")
//                try RowModelForTableWithoutPrimaryKey().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithoutPrimaryKeyCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (name TEXT)")
//                try RowModelForTableWithoutPrimaryKey().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithoutPrimaryKeyCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (name TEXT)")
//                RowModelForTableWithoutPrimaryKey().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelForTableWithMultipleColumnsPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRowModelForTableWithMultipleColumnsPrimaryKeyCanNotBeFetchedByID() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (a TEXT, b TEXT, PRIMARY KEY(a,b))")
//                RowModelForTableWithMultipleColumnsPrimaryKey.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RowModelWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary
    
    // CRASH TEST: this test must crash
//    func testRowModelWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionaryCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE models (id INTEGER PRIMARY KEY, name TEXT)")
//                try RowModelWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary().insert(db)
//            }
//        }
//    }
}
