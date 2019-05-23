import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class RecordWithoutDatabaseTableName: Record { }

private class RecordWithInexistingDatabaseTable: Record {
    override class var databaseTableName: String {
        return "foo"
    }
}

private class RecordWithEmptyPersistentDictionary : Record {
    override class var databaseTableName: String {
        return "records"
    }
}

private class RecordWithNilPrimaryKey : Record {
    override class var databaseTableName: String {
        return "records"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = nil
    }
}

private class RecordForTableWithoutPrimaryKey : Record {
    override class var databaseTableName: String {
        return "records"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["name"] = "foo"
    }
}

private class RecordForTableWithMultipleColumnsPrimaryKey : Record {
    override class var databaseTableName: String {
        return "records"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["name"] = "foo"
    }
}

private class RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary : Record {
    override class var databaseTableName: String {
        return "records"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["name"] = "foo"
    }
}

class RecordCrashTests: GRDBCrashTestCase {
    
    // =========================================================================
    // MARK: - RecordWithoutDatabaseTableName
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByID() {
        assertCrash("subclass must override") {
            dbQueue.inDatabase { db in
                _ = RecordWithoutDatabaseTableName.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordWithoutDatabaseTableNameCanNotBeFetchedByKey() {
        assertCrash("subclass must override") {
            dbQueue.inDatabase { db in
                _ = RecordWithoutDatabaseTableName.fetchOne(db, key: ["foo": "bar"])
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
                _ = RecordWithInexistingDatabaseTable.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordWithInexistingDatabaseTableCanNotBeFetchedByKey() {
        assertCrash("SQLite error 1 with statement `SELECT * FROM \"foo\" WHERE (\"id\" = ?)`: no such table: foo") {
            dbQueue.inDatabase { db in
                _ = RecordWithInexistingDatabaseTable.fetchOne(db, key: ["id": 1])
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
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().insert(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistentDictionaryCanNotBeUpdated() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().update(db)
            }
        }
    }

    func testRecordWithEmptyPersistentDictionaryCanNotBeSaved() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().save(db)
            }
        }
    }

    func testRecordWithEmptyPersistentDictionaryCanNotBeDeleted() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithEmptyPersistentDictionary().delete(db)
            }
        }
    }
    
    func testRecordWithEmptyPersistentDictionaryCanNotBeTestedForExistence() {
        assertCrash("RecordWithEmptyPersistentDictionary.persistentDictionary: invalid empty dictionary") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithEmptyPersistentDictionary().exists(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithNilPrimaryKey
    
    func testRecordWithNilPrimaryKeyCanNotBeUpdated() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().update(db)
            }
        }
    }
    
    func testRecordWithNilPrimaryKeyCanNotBeDeleted() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                try RecordWithNilPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordWithNilPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("invalid primary key in <RecordWithNilPrimaryKey id:nil>") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY)")
                RecordWithNilPrimaryKey().exists(db)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordForTableWithoutPrimaryKey
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("expected single column primary key in table: records") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (name TEXT)")
                _ = RecordForTableWithoutPrimaryKey.fetchOne(db, key: 1)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeUpdated() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().update(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeDeleted() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (name TEXT)")
                try RecordForTableWithoutPrimaryKey().delete(db)
            }
        }
    }
    
    func testRecordForTableWithoutPrimaryKeyCanNotBeTestedForExistence() {
        assertCrash("invalid primary key in <RecordForTableWithoutPrimaryKey name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (name TEXT)")
                RecordForTableWithoutPrimaryKey().exists(db)
            }
        }
    }

    
    // =========================================================================
    // MARK: - RecordForTableWithMultipleColumnsPrimaryKey
    
    func testRecordForTableWithMultipleColumnsPrimaryKeyCanNotBeFetchedByID() {
        assertCrash("expected single column primary key in table: records") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (a TEXT, b TEXT, PRIMARY KEY(a,b))")
                _ = RecordForTableWithMultipleColumnsPrimaryKey.fetchOne(db, key: 1)
            }
        }
    }
    
    
    // =========================================================================
    // MARK: - RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary
    
    func testRecordWithRowIDPrimaryKeyNotExposedInPersistentDictionaryCanNotBeInserted() {
        assertCrash("invalid primary key in <RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary name:\"foo\">") {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "CREATE TABLE records (id INTEGER PRIMARY KEY, name TEXT)")
                try RecordWithRowIDPrimaryKeyNotExposedInPersistentDictionary().update(db)
            }
        }
    }
}
