// All tests in this file must crash.
//
// To run those tests, run the GRDBOSXCrashTests target, and verify that each
// test crashes with the expected error message.

import XCTest
import GRDB


// MARK: - Support

class RecordWithoutDatabaseTableName: Record { }

class RecordWithInexistingDatabaseTable: Record {
    override static func databaseTableName() -> String {
        return "foo"
    }
}

class RecordWithEmptyPersistentDictionary : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
}

class RecordWithNilPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": nil]
    }
}

class RecordForTableWithoutPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordForTableWithMultipleColumnsPrimaryKey : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

class RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary : Record {
    override static func databaseTableName() -> String {
        return "records"
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": "foo"]
    }
}

// A type that adopts DatabaseValueConvertible but does not adopt StatementColumnConvertible
struct IntConvertible: DatabaseValueConvertible {
    let int: Int
    init(int: Int) {
        self.int = int
    }
    var databaseValue: DatabaseValue {
        return int.databaseValue
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
        assertCrash("already registered migration: \"foo\"") {
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
        assertCrash("Database was not used on the correct thread: execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). If you get this error while iterating the result of a fetch() method, consider using the array returned by fetchAll() instead.") {
            var rows: DatabaseSequence<Row>?
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT)")
                rows = Row.fetch(db, "SELECT * FROM persons")
            }
            let _ = rows!.generate()
        }
    }
    
    func testRowSequenceCanNotBeIteratedOutsideOfDatabaseQueue() {
        assertCrash("Database was not used on the correct thread: execute your statements inside DatabaseQueue.inDatabase() or DatabaseQueue.inTransaction(). If you get this error while iterating the result of a fetch() method, consider using the array returned by fetchAll() instead.") {
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
    
    func testInvalidStatementArguments() {
        assertCrash("SQLite error 1 with statement `INSERT INTO persons (name, age) VALUES (:name, :age)`: missing statement argument(s): age") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                try! db.execute("INSERT INTO persons (name, age) VALUES (:name, :age)", arguments: ["name": "Arthur"])
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', ?);`: wrong number of statement arguments: 0") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);")
                    XCTFail("Expected Error")
                } catch {
                    XCTAssertTrue(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age").isEmpty)
                }
                
                return .Rollback
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', ?);`: wrong number of statement arguments: 0") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);",
                        arguments: [41])
                    XCTFail("Expected Error")
                } catch {
                    // Partial fail
                    XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [41])
                }
                
                return .Rollback
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', :age1);`: missing statement argument(s): age1") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age1);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age2);")
                    XCTFail("Expected Error")
                } catch {
                    XCTAssertTrue(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age").isEmpty)
                }
                return .Rollback
            }
        }
        
        assertCrash("SQLite error 21 with statement `INSERT INTO persons (name, age) VALUES ('Arthur', :age2);`: missing statement argument(s): age2") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age1);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age2);",
                        arguments: ["age1": 41])
                    XCTFail("Expected Error")
                } catch {
                    // Partial fail
                    XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [41])
                }
                return .Rollback
            }
        }
        
        assertCrash("wrong number of statement arguments: 3") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age1);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', :age2);",
                        arguments: [41, 32, 17])
                    XCTFail("Expected Error")
                } catch {
                    // Partial fail
                    XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [32, 41])
                }
                return .Rollback
            }
        }
        
        assertCrash("wrong number of statement arguments: 3") {
            try dbQueue.inTransaction { db in
                do {
                    try db.execute("CREATE TABLE persons (name TEXT, age INT)")
                    try db.execute(
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);" +
                        "INSERT INTO persons (name, age) VALUES ('Arthur', ?);",
                        arguments: [41, 32, 17])
                    XCTFail("Expected Error")
                } catch {
                    // Partial fail
                    XCTAssertEqual(Int.fetchAll(db, "SELECT age FROM persons ORDER BY age"), [32, 41])
                }
                return .Rollback
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithoutDatabaseTableName
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByID() {
        assertCrash("subclass must override") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByKey() {
        assertCrash("subclass must override") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeInserted() {
        assertCrash("subclass must override") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().insert(db)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeUpdated() {
        assertCrash("subclass must override") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().update(db)
            }
        }
    }

    func testRecordWithoutDatabaseTableNameCanNotBeSaved() {
        assertCrash("subclass must override") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().save(db)
            }
        }
    }

    func testRecordWithoutDatabaseTableNameCanNotBeDeleted() {
        assertCrash("subclass must override") {
            try dbQueue.inDatabase { db in
                try RecordWithoutDatabaseTableName().delete(db)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeTestedForExistence() {
        assertCrash("subclass must override") {
            dbQueue.inDatabase { db in
                RecordWithoutDatabaseTableName().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordWithInexistingDatabaseTable
    
    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByID() {
        assertCrash("no such table: foo") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByKey() {
        assertCrash("SQLite error 1 with statement `SELECT * FROM \"foo\" WHERE (\"id\" = ?)`: no such table: foo") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable.fetchOne(db, key: ["id": 1])
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeInserted() {
        assertCrash("no such table: foo") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().insert(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeUpdated() {
        assertCrash("no such table: foo") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().update(db)
            }
        }
    }

    func testRecordWithInexistingDatabaseTableCanNotBeSaved() {
        assertCrash("no such table: foo") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().save(db)
            }
        }
    }

    func testRecordWithInexistingDatabaseTableCanNotBeDeleted() {
        assertCrash("no such table: foo") {
            try dbQueue.inDatabase { db in
                try RecordWithInexistingDatabaseTable().delete(db)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeTestedForExistence() {
        assertCrash("no such table: foo") {
            dbQueue.inDatabase { db in
                RecordWithInexistingDatabaseTable().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordWithEmptyPersistentDictionary
    
    func testRecordWithEmptyPersistentDictionaryCanNotBeInserted() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().insert(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistentDictionaryCanNotBeUpdated() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().update(db)
            }
        }
    }

    func testRecordWithEmptyPersistentDictionaryCanNotBeSaved() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().save(db)
            }
        }
    }

    func testRecordWithEmptyPersistentDictionaryCanNotBeDeleted() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().delete(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistentDictionaryCanNotBeTestedForExistence() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithEmptyPersistentDictionary().exists(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithNilPrimaryKey
    
    func testRecordWithNilPrimaryKeyCanNotBeUpdated() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().update(db)
            }
        }
    }

    func testRecordWithNilPrimaryKeyCanNotBeDeleted() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordWithNilPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithNilPrimaryKey().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordForTableWithoutPrimaryKey
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("expected single column primary key in table: records") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                RecordForTableWithoutPrimaryKey.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeUpdated() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().update(db)
            }
        }
    }

    func testRecordForTableWithoutPrimaryKeyCanNotBeDeleted() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (name TEXT)")
                RecordForTableWithoutPrimaryKey().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordForTableWithMultipleColumnsPrimaryKey
    
    func testRecordForTableWithMultipleColumnsPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("expected single column primary key in table: records") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (a TEXT, b TEXT, PRIMARY KEY(a,b))")
                RecordForTableWithMultipleColumnsPrimaryKey.fetchOne(db, key: 1)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary
    
    func testRecordWithRowIDPrimaryKeyNotExposedInPersistentDictionaryCanNotBeInserted() {
        assertCrash("invalid primary key in <RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, name TEXT)")
                try RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary().update(db)
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
        assertCrash("could not convert NULL to IntConvertible.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = IntConvertible.fetch(statement)
                for _ in sequence { }
            }
        }
    }

    func testCrashFetchAllDatabaseValueConvertibleFromStatement() {
        assertCrash("could not convert NULL to IntConvertible.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let _ = IntConvertible.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchDatabaseValueConvertibleFromDatabase() {
        assertCrash("could not convert NULL to IntConvertible.") {
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
        assertCrash("could not convert NULL to IntConvertible.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let _ = IntConvertible.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }

    func testCrashDatabaseValueConvertibleInvalidConversionFromNULL() {
        assertCrash("could not convert NULL to IntConvertible.") {
            let row = Row(["int": nil])
            let _ = row.value(named: "int") as IntConvertible
        }
    }

    func testCrashDatabaseValueConvertibleInvalidConversionFromInvalidType() {
        assertCrash("could not convert \"foo\" to IntConvertible") {
            let row = Row(["int": "foo"])
            let _ = row.value(named: "int") as IntConvertible
        }
    }
    
    
    // =========================================================================
    // MARK: - StatementColumnConvertible
    
    func testCrashFetchStatementColumnConvertibleFromStatement() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let sequence = Int.fetch(statement)
                for _ in sequence { }
            }
        }
    }

    func testCrashFetchAllStatementColumnConvertibleFromStatement() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let statement = try db.selectStatement("SELECT int FROM ints ORDER BY int")
                let _ = Int.fetchAll(statement)
            }
        }
    }
    
    func testCrashFetchStatementColumnConvertibleFromDatabase() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let sequence = Int.fetch(db, "SELECT int FROM ints ORDER BY int")
                for _ in sequence { }
            }
        }
    }

    func testCrashFetchAllStatementColumnConvertibleFromDatabase() {
        assertCrash("could not convert NULL to Int.") {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (int Int)")
                try db.execute("INSERT INTO ints (int) VALUES (1)")
                try db.execute("INSERT INTO ints (int) VALUES (NULL)")
                
                let _ = Int.fetchAll(db, "SELECT int FROM ints ORDER BY int")
            }
        }
    }

}
