import XCTest
import GRDB

private enum MaybeRemoteMaybeLocalIdError: Error {
    case mustHaveLocalIDorRemoteID
}

// MaybeRemoteMaybeLocalID is a record that might have a local id, or might have a remote id, or possibly both.
// So its primary key is a combination of the local and remote ids,
// permitting one or the other (but not both) to be null
private struct MaybeRemoteMaybeLocalID : Codable, MutablePersistableRecord, FetchableRecord {
    let localID: UInt64?
    let remoteID: UInt64?
    var thing: String
    
    init(localID: UInt64? = nil, remoteID: UInt64? = nil, thing: String) throws {
        guard localID != nil || remoteID != nil else { throw MaybeRemoteMaybeLocalIdError.mustHaveLocalIDorRemoteID }
        self.localID = localID
        self.remoteID = remoteID
        self.thing = thing
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE maybeRemoteMaybeLocalID (
                localID INT UNIQUE,
                remoteID INT UNIQUE,
                thing TEXT NOT NULL,
                PRIMARY KEY (localID, remoteID),
                CONSTRAINT check_primary CHECK (localID IS NOT NULL OR remoteID IS NOT NULL)
            )
            """)
    }
}


class RecordPrimaryKeyMultipleSomeNilTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createMaybeRemoteMaybeLocalID", migrate: MaybeRemoteMaybeLocalID.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Insert
    
    // This works fine
    func testInsert() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.insert(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM maybeRemoteMaybeLocalID WHERE localID = ?", arguments: [record.localID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    // MARK: - Update
    
    /// This fails, because it generates the sql something like:
    /// `UPDATE ... WHERE "localID"=1 AND "remoteID"=NULL`
    /// where I was expecting it to be generating something like:
    ///  `UPDATE ... WHERE "localID"=1 AND "remoteID" IS NULL`
    func testUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.insert(db)
            record.thing = "Local One Updated"
            try record.update(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM maybeRemoteMaybeLocalID WHERE localID = ?", arguments: [record.localID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    // MARK: - Delete
    
    func testDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.insert(db)
            try record.delete(db)
            do {
                try record.update(db)
                XCTFail("Expected PersistenceError.recordNotFound")
            } catch let PersistenceError.recordNotFound(databaseTableName: databaseTableName, key: key) {
                // Expected PersistenceError.recordNotFound
                XCTAssertEqual(databaseTableName, "maybeRemoteMaybeLocalID")
                XCTAssertEqual(DatabaseValue.null, key["remoteID"])
                XCTAssertEqual(1.databaseValue, key["localID"])
            }
        }
    }
    
    // MARK: - Exists
    
    func testExistsFalse() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            XCTAssertFalse(try record.exists(db))
        }
    }
    
    func testExistsTrue() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.insert(db)
            XCTAssertTrue(try record.exists(db))
        }
    }
    
    // MARK: - Save
    
    func testSavesNew() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM maybeRemoteMaybeLocalID WHERE localID = ?", arguments: [record.localID])!
            assert(record, isEncodedIn: row)
        }
    }
    
    func testSavesUpdate() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var record = try MaybeRemoteMaybeLocalID(localID: 1, thing: "Local One")
            try record.insert(db)
            record.thing = "Local One Updated"
            try record.save(db)
            
            let row = try Row.fetchOne(db, sql: "SELECT * FROM maybeRemoteMaybeLocalID WHERE localID = ?", arguments: [record.localID])!
            assert(record, isEncodedIn: row)
        }
    }
    
}
