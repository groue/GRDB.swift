import XCTest
import GRDB

// MaybeNullPrimaryKey is a record that might have a null primary key.
//
// From the [SQLite documentation](https://www.sqlite.org/lang_createtable.html#the_primary_key):
// > According to the SQL standard, PRIMARY KEY should always imply NOT NULL. Unfortunately, due to a bug in some early versions, this is not the case in SQLite. Unless the column is an INTEGER PRIMARY KEY or the table is a WITHOUT ROWID table or the column is declared NOT NULL, SQLite allows NULL values in a PRIMARY KEY column. SQLite could be fixed to conform to the standard, but doing so might break legacy applications. Hence, it has been decided to merely document the fact that SQLite allows NULLs in most PRIMARY KEY columns.
//
// [According to @groue](https://github.com/groue/GRDB.swift/issues/1023#issuecomment-893504893):
//
// > Since SQLite itself _allows_ NULL in primary keys, GRDB should accept this non-standard practice as well. At least when it does not create problems.


private struct PrimaryKeyNullable : Codable, MutablePersistableRecord, FetchableRecord {
    let id: String?
    var thing: String
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE primaryKeyNullable (
                id PRIMARY KEY,
                thing TEXT NOT NULL
            )
            """)
    }
}

class RecordPrimaryKeyNullableTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPrimaryKeyNullable", migrate: PrimaryKeyNullable.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    func testInsert() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testInsertNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id IS NULL")!
            assert(record, isEncodedIn: row)
        }
    }
    
    // MARK: - Update

    func testUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.insert(db)
            record.thing = "Thing One Updated"
            try record.update(db)

            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testUpdateNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.insert(db)
            record.thing = "Thing One Updated"
            try record.update(db)

            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id IS NULL")!
            assert(record, isEncodedIn: row)
        }
    }

    // MARK: - Delete

    func testDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "primaryKeyNullable")
                XCTAssertEqual("One".databaseValue, key["id"])
            }
        }
    }
    
    func testDeleteNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "primaryKeyNullable")
                XCTAssertEqual(DatabaseValue.null, key["id"])
            }
        }
    }

    // MARK: - Exists

    func testExistsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }
    
    func testExistsFalseNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            XCTAssertFalse(try record.exists(db))
        }
    }

    func testExistsTrueNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }

    // MARK: - Save

    func testSavesNew() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.save(db)

            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }

    func testSavesUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: "One", thing: "Thing One")
            try record.insert(db)
            record.thing = "Thing One Updated"
            try record.save(db)

            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id = ?", arguments: [record.id])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSavesNewNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.save(db)

            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id IS NULL")!
            assert(record, isEncodedIn: row)
        }
    }

    func testSavesUpdateNullPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = PrimaryKeyNullable(id: nil, thing: "Thing One")
            try record.insert(db)
            record.thing = "Thing One Updated"
            try record.save(db)
            let row = try Row.fetchOne(db, sql: "SELECT * FROM primaryKeyNullable WHERE id IS NULL")!
            assert(record, isEncodedIn: row)
        }
    }
    
}
