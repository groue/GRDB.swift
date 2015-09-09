import XCTest
import GRDB

class RecordWithoutDatabaseTableName: Record { }

class RecordWithInexistingDatabaseTable: Record {
    override static func databaseTableName() -> String? {
        return "foo"
    }
}

class RecordWithEmptyStoredDatabaseDictionary : Record {
    override static func databaseTableName() -> String? {
        return "records"
    }
}

class RecordWithNilPrimaryKey : Record {
    override static func databaseTableName() -> String? {
        return "records"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": nil]
    }
}

class RecordForTableWithoutPrimaryKey : Record {
    override static func databaseTableName() -> String? {
        return "records"
    }

    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordForTableWithMultipleColumnsPrimaryKey : Record {
    override static func databaseTableName() -> String? {
        return "records"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary : Record {
    override static func databaseTableName() -> String? {
        return "records"
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class InvalidRecordTests: GRDBTestCase {
    
    // =========================================================================
    // MARK: - RecordWithoutDatabaseTableName
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByID() {
//        dbQueue.inDatabase { db in
//            RecordWithoutDatabaseTableName.fetchOne(db, primaryKey: 1)
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByKey() {
//        dbQueue.inDatabase { db in
//            RecordWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithoutDatabaseTableName().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithoutDatabaseTableName().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithoutDatabaseTableName().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithoutDatabaseTableName().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithoutDatabaseTableName().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithoutDatabaseTableNameCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RecordWithoutDatabaseTableName().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RecordWithInexistingDatabaseTable
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByID() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RecordWithInexistingDatabaseTable.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByKey() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RecordWithInexistingDatabaseTable.fetchOne(db, key: ["id": 1])
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithInexistingDatabaseTable().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithInexistingDatabaseTable().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithInexistingDatabaseTable().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithInexistingDatabaseTable().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try RecordWithInexistingDatabaseTable().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithInexistingDatabaseTableCanNotBeTestedForExistence() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                RecordWithInexistingDatabaseTable().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RecordWithEmptyStoredDatabaseDictionary
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithEmptyStoredDatabaseDictionary().insert(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithEmptyStoredDatabaseDictionary().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeSaved() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithEmptyStoredDatabaseDictionary().save(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithEmptyStoredDatabaseDictionary().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithEmptyStoredDatabaseDictionary().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                RecordWithEmptyStoredDatabaseDictionary().exists(db)
//            }
//        }
//    }
    
    // =========================================================================
    // MARK: - RecordWithNilPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRecordWithNilPrimaryKeyCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithNilPrimaryKey().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithNilPrimaryKeyCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithNilPrimaryKey().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithNilPrimaryKeyCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                try RecordWithNilPrimaryKey().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordWithNilPrimaryKeyCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
//                RecordWithNilPrimaryKey().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RecordForTableWithoutPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithoutPrimaryKeyCanNotBeFetchedByID() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (name TEXT)")
//                RecordForTableWithoutPrimaryKey.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithoutPrimaryKeyCanNotBeUpdated() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (name TEXT)")
//                try RecordForTableWithoutPrimaryKey().update(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithoutPrimaryKeyCanNotBeDeleted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (name TEXT)")
//                try RecordForTableWithoutPrimaryKey().delete(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithoutPrimaryKeyCanNotBeReloaded() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (name TEXT)")
//                try RecordForTableWithoutPrimaryKey().reload(db)
//            }
//        }
//    }
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithoutPrimaryKeyCanNotBeTestedForExistence() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (name TEXT)")
//                RecordForTableWithoutPrimaryKey().exists(db)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RecordForTableWithMultipleColumnsPrimaryKey
    
    // CRASH TEST: this test must crash
//    func testRecordForTableWithMultipleColumnsPrimaryKeyCanNotBeFetchedByID() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (a TEXT, b TEXT, PRIMARY KEY(a,b))")
//                RecordForTableWithMultipleColumnsPrimaryKey.fetchOne(db, primaryKey: 1)
//            }
//        }
//    }
    
    
    // =========================================================================
    // MARK: - RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary
    
    // CRASH TEST: this test must crash
//    func testRecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionaryCanNotBeInserted() {
//        assertNoError {
//            try dbQueue.inDatabase { db in
//                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, name TEXT)")
//                try RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary().insert(db)
//            }
//        }
//    }
}
