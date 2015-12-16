// All tests in this file must crash.
//
// To run those tests, check the GRDBOSXTests and GRDBiOSTests membership.

import XCTest
import GRDB


// MARK: - Support

class RecordWithoutDatabaseTableName: Record { }

class RecordWithInexistingDatabaseTable: Record {
    override static func databaseTableName() -> String {
        return "foo"
    }
}

class RecordWithEmptyPersistedDictionary : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
}

class RecordWithNilPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["id": nil]
    }
}

class RecordForTableWithoutPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordForTableWithMultipleColumnsPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordWithRowIDPrimaryKeyNotExposedInPersistedDictionary : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

// A type that adopts DatabaseValueConvertible but does not adopt SQLiteStatementConvertible
struct IntConvertible: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return DatabaseValue(int64: Int64(int))
    }
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> IntConvertible? {
        guard let int = Int.fromDatabaseValue(databaseValue) else {
            return nil
        }
        return IntConvertible(int: int)
    }
}

// MARK: - CrashTests

class CrashTests: GRDBTestCase {
    
    // This method does not actually catch any crash.
    // But it expresses an intent :-)
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
            var rows: DatabaseSequence<Row>?
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                rows = Row.fetch(db, "SELECT * FROM persons")
            }
            let _ = rows!.generate()
        }
    }
    
    func testRowSequenceCanNotBeIteratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct queue.") {
            var generator: DatabaseGenerator<Row>?
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
    }

    
    // =========================================================================
    // MARK: - RecordWithEmptyPersistedDictionary
    
    func testRecordWithEmptyPersistedDictionaryCanNotBeInserted() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistedDictionary().insert(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistedDictionaryCanNotBeUpdated() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistedDictionary().update(db)
            }
        }
    }

    func testRecordWithEmptyPersistedDictionaryCanNotBeSaved() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistedDictionary().save(db)
            }
        }
    }

    func testRecordWithEmptyPersistedDictionaryCanNotBeDeleted() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistedDictionary().delete(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistedDictionaryCanNotBeReloaded() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistedDictionary().reload(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistedDictionaryCanNotBeTestedForExistence() {
        assertCrash("Invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithEmptyPersistedDictionary().exists(db)
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
    // MARK: - RecordWithRowIDPrimaryKeyNotExposedInPersistedDictionary
    
    func testRecordWithRowIDPrimaryKeyNotExposedInPersistedDictionaryCanNotBeInserted() {
        assertCrash("RecordWithRowIDPrimaryKeyNotExposedInPersistedDictionary.persistedDictionary must return the value for the primary key \"id\"") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, name TEXT)")
                try RecordWithRowIDPrimaryKeyNotExposedInPersistedDictionary().insert(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - Concurrency
    
    func testReaderCrashDuringExclusiveTransaction() {
        assertCrash("SQLite error 5 with statement `SELECT * FROM stuffs`: database is locked") {
            databasePath = "/tmp/GRDBTestReaderDuringExclusiveTransaction.sqlite"
            do { try NSFileManager.defaultManager().removeItemAtPath(databasePath) } catch { }
            let dbQueue1 = try! DatabaseQueue(path: databasePath)
            let dbQueue2 = try! DatabaseQueue(path: databasePath)
            
            try! dbQueue1.inDatabase { db in
                try db.execute("CREATE TABLE stuffs (id INTEGER PRIMARY KEY)")
            }
            
            let queue = NSOperationQueue()
            queue.maxConcurrentOperationCount = 2
            queue.addOperation(NSBlockOperation {
                do {
                    try dbQueue1.inTransaction(.Exclusive) { db in
                        sleep(2)    // let other queue try to read.
                        return .Commit
                    }
                }
                catch is DatabaseError {
                }
                catch {
                    XCTFail("\(error)")
                }
                })
            
            queue.addOperation(NSBlockOperation {
                dbQueue2.inDatabase { db in
                    sleep(1)    // let other queue open transaction
                    Row.fetch(db, "SELECT * FROM stuffs")   // Crash expected
                }
                })
            
            queue.waitUntilAllOperationsAreFinished()
        }
    }
    
    
    // =========================================================================
    // MARK: - DatabaseValueConvertible
    
    func testCrashFetchDatabaseValueConvertibleFromStatement() {
        assertCrash("Could not convert NULL to IntConvertible while iterating `SELECT int FROM ints ORDER BY int`.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = IntConvertible.fetch(statement)
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllDatabaseValueConvertibleFromStatement() {
        assertCrash("Could not convert NULL to IntConvertible while iterating `SELECT int FROM ints ORDER BY int`.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let _ = IntConvertible.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchDatabaseValueConvertibleFromDatabase() {
        assertCrash("Could not convert NULL to IntConvertible while iterating `SELECT int FROM ints ORDER BY int`.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = IntConvertible.fetch(db, "SELECT int FROM ints ORDER BY int")
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllDatabaseValueConvertibleFromDatabase() {
        assertCrash("Could not convert NULL to IntConvertible while iterating `SELECT int FROM ints ORDER BY int`.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let _ = IntConvertible.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }

    func testCrashDatabaseValueConvertibleInvalidConversionFromNULL() {
        assertCrash("Could not convert NULL to IntConvertible.") {
            let row = Row(dictionary: ["int": nil])
            let _ = row.value(named: "int") as IntConvertible
        }
    }
    
    func testCrashDatabaseValueConvertibleInvalidConversionFromInvalidType() {
        assertCrash("Could not convert \"foo\" to IntConvertible.") {
            let row = Row(dictionary: ["int": "foo"])
            let _ = row.value(named: "int") as IntConvertible
        }
    }
    
    
    // =========================================================================
    // MARK: - SQLiteStatementConvertible
    
    func testCrashFetchSQLiteStatementConvertibleFromStatement() {
        assertCrash("Found NULL") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Int.fetch(statement)
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllSQLiteStatementConvertibleFromStatement() {
        assertCrash("Found NULL") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = db.selectStatement("SELECT int FROM ints ORDER BY int")
                let _ = Int.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchSQLiteStatementConvertibleFromDatabase() {
        assertCrash("Found NULL") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Int.fetch(db, "SELECT int FROM ints ORDER BY int")
                for _ in sequence { }
            }
        }
    }
    
    func testCrashFetchAllSQLiteStatementConvertibleFromDatabase() {
        assertCrash("Found NULL") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let _ = Int.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }

}
