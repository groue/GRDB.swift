// All tests in this file must crash.
//
// To run those tests, check the GRDBOSXTests and GRDBiOSTests membership.

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

class CrashTests: GRDBTestCase {
    
    func assertCrash(message: String, @noescape block: () throws -> ()) {
        do {
            try block()
            XCTFail("Crash expected: \(message)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // =========================================================================
    // MARK: - Migrations
    
    func testMigrationNamesMustBeUnique() {
        assertCrash("Already registered migration: \"foo\"") {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("foo") { db in }
            migrator.registerMigration("foo") { db in }
        }
    }
    
    
    // =========================================================================
    // MARK: - Queue
    
    func testInDatabaseIsNotReentrant() {
        assertCrash("DatabaseQueue.inDatabase(_:) or DatabaseQueue.inTransaction(_:) was called reentrantly, which would lead to a deadlock.") {
            dbQueue.inDatabase { db in
                self.dbQueue.inDatabase { db in
                }
            }
        }
    }
    
    func testInTransactionInsideInDatabaseIsNotReentrant() {
        assertCrash("DatabaseQueue.inDatabase(_:) or DatabaseQueue.inTransaction(_:) was called reentrantly, which would lead to a deadlock.") {
            try dbQueue.inDatabase { db in
                try self.dbQueue.inTransaction { db in
                    return .Commit
                }
            }
        }
    }

    func testInTransactionIsNotReentrant() {
        assertCrash("DatabaseQueue.inDatabase(_:) or DatabaseQueue.inTransaction(_:) was called reentrantly, which would lead to a deadlock.") {
            try dbQueue.inTransaction { db in
                try self.dbQueue.inTransaction { db in
                    return .Commit
                }
                return .Commit
            }
        }
    }
    
    func testRowSequenceCanNotBeGeneratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct queue.") {
            var rows: AnySequence<Row>?
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                rows = Row.fetch(db, "SELECT * FROM persons")
            }
            rows!.generate()
        }
    }
    
    func testRowSequenceCanNotBeIteratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct queue.") {
            var generator: AnyGenerator<Row>?
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                generator = Row.fetch(db, "SELECT * FROM persons").generate()
            }
            generator!.next()
        }
    }
    
    
    // =========================================================================
    // MARK: - Statements
    
    func testExecuteDoesNotSupportMultipleStatement() {
        assertCrash("Invalid SQL string: multiple statements found.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT); CREATE TABLE books (name TEXT, age INT)")
            }
        }
    }
    
    func testInvalidNamedBinding() {
        assertCrash("Key not found in SQLite statement: `:XXX`") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["XXX": "foo", "name": "Arthur", "age": 41])
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordWithoutDatabaseTableName
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByID() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName.fetchOne(db, primaryKey: 1)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByKey() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeInserted() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().insert(db)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeUpdated() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().update(db)
            }
        }
    }

    func testRecordWithoutDatabaseTableNameCanNotBeSaved() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().save(db)
            }
        }
    }

    func testRecordWithoutDatabaseTableNameCanNotBeDeleted() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().delete(db)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeReloaded() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().reload(db)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeTestedForExistence() {
        assertCrash("Nil returned from RecordWithoutDatabaseTableName.databaseTableName()") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordWithInexistingDatabaseTable
    
    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByID() {
        assertCrash("Table \"foo\" does not exist.") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable.fetchOne(db, primaryKey: 1)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByKey() {
        assertCrash("no such table: foo") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable.fetchOne(db, key: ["id": 1])
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeInserted() {
        assertCrash("Table \"foo\" does not exist.") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().insert(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeUpdated() {
        assertCrash("Table \"foo\" does not exist.") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().update(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeSaved() {
        assertCrash("Table \"foo\" does not exist.") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().save(db)
            }
        }
    }

    func testRecordWithInexistingDatabaseTableCanNotBeDeleted() {
        assertCrash("Table \"foo\" does not exist.") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().delete(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeReloaded() {
        assertCrash("Table \"foo\" does not exist.") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().reload(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeTestedForExistence() {
        assertCrash("Table \"foo\" does not exist.") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable().exists(db)
            }
        }
        XCTFail("Crash expected")
    }

    
    // =========================================================================
    // MARK: - RecordWithEmptyStoredDatabaseDictionary
    
    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeInserted() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyStoredDatabaseDictionary().insert(db)
            }
        }
    }
    
    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeUpdated() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyStoredDatabaseDictionary().update(db)
            }
        }
    }

    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeSaved() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyStoredDatabaseDictionary().save(db)
            }
        }
    }

    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeDeleted() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyStoredDatabaseDictionary().delete(db)
            }
        }
    }
    
    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeReloaded() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyStoredDatabaseDictionary().reload(db)
            }
        }
    }
    
    func testRecordWithEmptyStoredDatabaseDictionaryCanNotBeTestedForExistence() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithEmptyStoredDatabaseDictionary().exists(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithNilPrimaryKey
    
    func testRecordWithNilPrimaryKeyCanNotBeUpdated() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().update(db)
            }
        }
    }

    func testRecordWithNilPrimaryKeyCanNotBeDeleted() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordWithNilPrimaryKeyCanNotBeReloaded() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().reload(db)
            }
        }
    }
    
    func testRecordWithNilPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithNilPrimaryKey().exists(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordForTableWithoutPrimaryKey
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("Primary key of table \"records\" is not made of a single column.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                RecordForTableWithoutPrimaryKey.fetchOne(db, primaryKey: 1)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeUpdated() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().update(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeDeleted() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeReloaded() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().reload(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("Invalid primary key") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                RecordForTableWithoutPrimaryKey().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordForTableWithMultipleColumnsPrimaryKey
    
    func testRecordForTableWithMultipleColumnsPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("Primary key of table \"records\" is not made of a single column.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (a TEXT, b TEXT, PRIMARY KEY(a,b))")
                RecordForTableWithMultipleColumnsPrimaryKey.fetchOne(db, primaryKey: 1)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary
    
    func testRecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionaryCanNotBeInserted() {
        assertCrash("RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary.storedDatabaseDictionary must return the value for the primary key \"id\"") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, name TEXT)")
                try RecordWithRowIDPrimaryKeyNotExposedInStoredDatabaseDictionary().insert(db)
            }
        }
    }
}
