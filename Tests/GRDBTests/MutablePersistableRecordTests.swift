import XCTest
import GRDB

private struct MutablePersistableRecordPerson : MutablePersistableRecord {
    var id: Int64?
    var name: String?
    var age: Int?
    
    static let databaseTableName = "persons"
    
    func encode(to container: inout PersistenceContainer) {
        // mangle cases
        container["iD"] = id
        container["NAme"] = name
        container["aGe"] = age
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        let inserted = try insert()
        XCTAssertNotNil(inserted.rowID)
        XCTAssertEqual(inserted.rowIDColumn, "id")
        XCTAssertEqual(inserted.persistenceContainer["iD"]?.databaseValue, inserted.rowID.databaseValue)
        XCTAssertEqual(inserted.persistenceContainer["id"]?.databaseValue, inserted.rowID.databaseValue)
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        XCTAssertEqual(inserted.rowIDColumn, "id")
        XCTAssertEqual(inserted.persistenceContainer["iD"]?.databaseValue, inserted.rowID.databaseValue)
        XCTAssertEqual(inserted.persistenceContainer["id"]?.databaseValue, inserted.rowID.databaseValue)
        id = inserted.rowID
    }
}

private struct MutablePersistableRecordCountry : MutablePersistableRecord {
    var rowID: Int64?
    var isoCode: String
    var name: String
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        XCTAssertNil(inserted.rowIDColumn)
        rowID = inserted.rowID
    }
}

private class Callbacks {
    var willInsertCount = 0
    var aroundInsertEnterCount = 0
    var aroundInsertExitCount = 0
    var didInsertCount = 0
    
    var willUpdateCount = 0
    var aroundUpdateEnterCount = 0
    var aroundUpdateExitCount = 0
    var didUpdateCount = 0
    
    var willSaveCount = 0
    var aroundSaveEnterCount = 0
    var aroundSaveExitCount = 0
    var didSaveCount = 0
    
    var willDeleteCount = 0
    var aroundDeleteEnterCount = 0
    var aroundDeleteExitCount = 0
    var didDeleteCount = 0
}

private struct MutablePersistableRecordCustomizedCountry : MutablePersistableRecord {
    var rowID: Int64?
    var isoCode: String
    var name: String
    let callbacks = Callbacks()
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
    }
    
    mutating func willInsert(_ db: Database) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        callbacks.willInsertCount += 1
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        
        callbacks.aroundInsertEnterCount += 1
        _ = try insert()
        callbacks.aroundInsertExitCount += 1
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        callbacks.didInsertCount += 1
        rowID = inserted.rowID
    }
    
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        callbacks.willUpdateCount += 1
    }
    
    func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        
        callbacks.aroundUpdateEnterCount += 1
        _ = try update()
        callbacks.aroundUpdateExitCount += 1
    }
    
    func didUpdate(_ updated: PersistenceSuccess) {
        callbacks.didUpdateCount += 1
    }
    
    func willSave(_ db: Database) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        callbacks.willSaveCount += 1
    }
    
    func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        
        callbacks.aroundSaveEnterCount += 1
        _ = try save()
        callbacks.aroundSaveExitCount += 1
    }
    
    func didSave(_ saved: PersistenceSuccess) {
        callbacks.didSaveCount += 1
    }
    
    func willDelete(_ db: Database) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        callbacks.willDeleteCount += 1
    }
    
    func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
        // Make sure database can be used
        try db.execute(sql: "SELECT 1")
        
        callbacks.aroundDeleteEnterCount += 1
        _ = try delete()
        callbacks.aroundDeleteExitCount += 1
    }
    
    func didDelete(deleted: Bool) {
        callbacks.didDeleteCount += 1
    }
}

private struct PartialPlayer: Codable, MutablePersistableRecord, FetchableRecord {
    static let databaseTableName = "player"
    let callbacks = Callbacks()
    var id: Int64?
    var name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    mutating func willInsert(_ db: Database) throws {
        callbacks.willInsertCount += 1
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        callbacks.aroundInsertEnterCount += 1
        _ = try insert()
        callbacks.aroundInsertExitCount += 1
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
        callbacks.didInsertCount += 1
    }
    
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        callbacks.willUpdateCount += 1
    }
    
    func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
        callbacks.aroundUpdateEnterCount += 1
        _ = try update()
        callbacks.aroundUpdateExitCount += 1
    }
    
    func didUpdate(_ updated: PersistenceSuccess) {
        callbacks.didUpdateCount += 1
    }
    
    func willSave(_ db: Database) throws {
        callbacks.willSaveCount += 1
    }
    
    func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
        callbacks.aroundSaveEnterCount += 1
        _ = try save()
        callbacks.aroundSaveExitCount += 1
    }
    
    func didSave(_ saved: PersistenceSuccess) {
        callbacks.didSaveCount += 1
    }
    
    func willDelete(_ db: Database) throws {
        callbacks.willDeleteCount += 1
    }
    
    func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
        callbacks.aroundDeleteEnterCount += 1
        _ = try delete()
        callbacks.aroundDeleteExitCount += 1
    }
    
    func didDelete(deleted: Bool) {
        callbacks.didDeleteCount += 1
    }
}

private struct FullPlayer: Codable, MutablePersistableRecord, FetchableRecord {
    static let databaseTableName = "player"
    var id: Int64?
    var name: String
    var score: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, score
    }
    
    let callbacks = Callbacks()
    
    mutating func willInsert(_ db: Database) throws {
        callbacks.willInsertCount += 1
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        callbacks.aroundInsertEnterCount += 1
        _ = try insert()
        callbacks.aroundInsertExitCount += 1
    }
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
        callbacks.didInsertCount += 1
    }
    
    func willUpdate(_ db: Database, columns: Set<String>) throws {
        callbacks.willUpdateCount += 1
    }
    
    func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
        callbacks.aroundUpdateEnterCount += 1
        _ = try update()
        callbacks.aroundUpdateExitCount += 1
    }
    
    func didUpdate(_ updated: PersistenceSuccess) {
        callbacks.didUpdateCount += 1
    }
    
    func willSave(_ db: Database) throws {
        callbacks.willSaveCount += 1
    }
    
    func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
        callbacks.aroundSaveEnterCount += 1
        _ = try save()
        callbacks.aroundSaveExitCount += 1
    }
    
    func didSave(_ saved: PersistenceSuccess) {
        callbacks.didSaveCount += 1
    }
    
    func willDelete(_ db: Database) throws {
        callbacks.willDeleteCount += 1
    }
    
    func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
        callbacks.aroundDeleteEnterCount += 1
        _ = try delete()
        callbacks.aroundDeleteExitCount += 1
    }
    
    func didDelete(deleted: Bool) {
        callbacks.didDeleteCount += 1
    }
}

class MutablePersistableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name NOT NULL,
                    age INTEGER);
                CREATE TABLE countries (
                    isoCode TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL);
                CREATE TABLE player(
                    id INTEGER PRIMARY KEY,
                    name NOT NULL UNIQUE, -- UNIQUE for upsert tests
                    score INTEGER NOT NULL DEFAULT 1000);
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    // MARK: - MutablePersistableRecordPerson
    
    func testInsertMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person.insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    func testInsertedMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = try MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24).inserted(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    func testUpdateWithoutExplicitPrimaryKeyButWithExplicitRowIDSupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE record(name)")
            
            struct Record: Codable, MutablePersistableRecord {
                var rowID: Int64?
                var name: String
                mutating func didInsert(_ inserted: InsertionSuccess) {
                    rowID = inserted.rowID
                }
            }
            
            var record1 = Record(name: "Arthur")
            var record2 = Record(name: "Barbara")
            try record1.insert(db)
            try record2.insert(db)
            record1.name = "Craig"
            try record1.update(db)
            
            let names = try String.fetchAll(db, sql: "SELECT name FROM record ORDER BY rowid")
            XCTAssertEqual(names, ["Craig", "Barbara"])
        }
    }
    
    func testUpdateWithoutExplicitPrimaryKeyAndWithoutExplicitRowIDSupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE record(name)")
            
            struct Record: Codable, PersistableRecord {
                var name: String
            }
            
            let record = Record(name: "Arthur")
            try record.insert(db)
            do {
                try record.update(db)
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound { }
        }
    }
    
    func testUpdateMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person1.insert(db)
            var person2 = MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24)
            try person2.insert(db)
            
            person1.name = "Craig"
            try person1.update(db)
            XCTAssertTrue([
                "UPDATE \"persons\" SET \"age\"=24, \"name\"='Craig' WHERE \"id\"=1",
                "UPDATE \"persons\" SET \"name\"='Craig', \"age\"=24 WHERE \"id\"=1"
            ].contains(self.lastSQLQuery))
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
        }
    }
    
    func testPartialUpdateMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person1.insert(db)
            var person2 = MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 36)
            try person2.insert(db)
            
            do {
                person1.name = "Craig"
                try person1.update(db, columns: [String]())
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"id\"=1 WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                XCTAssertEqual(rows[0]["name"] as String, "Arthur")
                XCTAssertEqual(rows[0]["age"] as Int, 24)
                XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                person1.name = "Craig"
                person1.age = 25
                try person1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"name\"='Craig' WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                XCTAssertEqual(rows[0]["name"] as String, "Craig")
                XCTAssertEqual(rows[0]["age"] as Int, 24)
                XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                person1.name = "David"
                try person1.update(db, columns: ["AgE"])    // case insensitivity
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"age\"=25 WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                XCTAssertEqual(rows[0]["name"] as String, "Craig")
                XCTAssertEqual(rows[0]["age"] as Int, 25)
                XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
        }
    }
    
    func testSaveMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            var person2 = MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24)
            try person2.save(db)
            
            person1.name = "Craig"
            try person1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            
            try person1.delete(db)
            try person1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
        }
    }
    
    func testSavedMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = try MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24).saved(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            let person2 = try MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24).saved(db)
            
            person1.name = "Craig"
            var savedPerson1 = try person1.saved(db)
            XCTAssertEqual(person1.id, savedPerson1.id)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            
            try person1.delete(db)
            savedPerson1 = try person1.saved(db)
            XCTAssertEqual(person1.id, savedPerson1.id)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, savedPerson1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
        }
    }
    
    func testDeleteWithoutExplicitPrimaryKeyButWithExplicitRowIDSupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE record(name)")
            
            struct Record: Codable, MutablePersistableRecord {
                var rowID: Int64?
                var name: String
                mutating func didInsert(_ inserted: InsertionSuccess) {
                    rowID = inserted.rowID
                }
            }
            
            var record1 = Record(name: "Arthur")
            var record2 = Record(name: "Barbara")
            try record1.insert(db)
            try record2.insert(db)
            try record1.delete(db)
            
            let names = try String.fetchAll(db, sql: "SELECT name FROM record ORDER BY rowid")
            XCTAssertEqual(names, ["Barbara"])
        }
    }
    
    func testDeleteWithoutExplicitPrimaryKeyAndWithoutExplicitRowIDSupport() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE record(name)")
            
            struct Record: Codable, PersistableRecord {
                var name: String
            }
            
            let record = Record(name: "Arthur")
            try record.insert(db)
            try XCTAssertFalse(record.delete(db))
            
            let names = try String.fetchAll(db, sql: "SELECT name FROM record ORDER BY rowid")
            XCTAssertEqual(names, ["Arthur"])
        }
    }
    
    func testDeleteMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person1.insert(db)
            var person2 = MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24)
            try person2.insert(db)
            
            var deleted = try person1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try person1.delete(db)
            XCTAssertFalse(deleted)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Barbara")
        }
    }
    
    func testExistsMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person.insert(db)
            XCTAssertTrue(try person.exists(db))
            
            try person.delete(db)
            XCTAssertFalse(try person.exists(db))
        }
    }
    
    func testMutablePersistableRecordPersonDatabaseDictionary() throws {
        let person = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
        let dict = try person.databaseDictionary
        XCTAssertEqual(dict, ["iD": DatabaseValue.null, "NAme": "Arthur".databaseValue, "aGe": 24.databaseValue])
    }
    
    // MARK: - MutablePersistableRecordCountry
    
    func testInsertMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country.insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testInsertedMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = try MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France").inserted(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testUpdateMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.insert(db)
            var country2 = MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db)
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testSaveMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
            
            var country2 = MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "United States")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
        }
    }
    
    func testSavedMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = try MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France").saved(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = try MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States").saved(db)
            
            country1.name = "France Métropolitaine"
            var savedCountry1 = try country1.saved(db)
            XCTAssertEqual(country1.rowID, savedCountry1.rowID)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            savedCountry1 = try country1.saved(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "United States")
            XCTAssertEqual(rows[1]["rowID"] as Int64, savedCountry1.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
        }
    }
    
    func testDeleteMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.insert(db)
            var country2 = MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.insert(db)
            
            var deleted = try country1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try country1.delete(db)
            XCTAssertFalse(deleted)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }
    
    func testExistsMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country.insert(db)
            XCTAssertTrue(try country.exists(db))
            
            try country.delete(db)
            XCTAssertFalse(try country.exists(db))
        }
    }
    
    // MARK: - MutablePersistableRecordCustomizedCountry
    
    func testInsertMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France")
            try country.insert(db)
            
            XCTAssertEqual(country.callbacks.willInsertCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country.callbacks.willUpdateCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateEnterCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateExitCount, 0)
            XCTAssertEqual(country.callbacks.didUpdateCount, 0)
            
            XCTAssertEqual(country.callbacks.willSaveCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveExitCount, 1)
            XCTAssertEqual(country.callbacks.didSaveCount, 1)
            
            XCTAssertEqual(country.callbacks.willDeleteCount, 0)
            XCTAssertEqual(country.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(country.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(country.callbacks.didDeleteCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testUpdateMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France")
            try country1.insert(db)
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "US",
                name: "United States")
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db)
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            XCTAssertEqual(country1.callbacks.willInsertCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country1.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country1.callbacks.willUpdateCount, 1)
            XCTAssertEqual(country1.callbacks.aroundUpdateEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(country1.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 2)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 2)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(country1.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testRecordErrorMutablePersistableRecordCustomizedCountry() throws {
        let country = MutablePersistableRecordCustomizedCountry(
            rowID: nil,
            isoCode: "FR",
            name: "France")
        
        let dbQueue = try makeDatabaseQueue()
        do {
            try dbQueue.inDatabase { db in
                try country.update(db)
            }
            XCTFail("Expected RecordError")
        } catch RecordError.recordNotFound(databaseTableName: "countries", key: ["isoCode": "FR".databaseValue]) { }
        
        XCTAssertEqual(country.callbacks.willInsertCount, 0)
        XCTAssertEqual(country.callbacks.aroundInsertEnterCount, 0)
        XCTAssertEqual(country.callbacks.aroundInsertExitCount, 0)
        XCTAssertEqual(country.callbacks.didInsertCount, 0)
        
        XCTAssertEqual(country.callbacks.willUpdateCount, 1)
        XCTAssertEqual(country.callbacks.aroundUpdateEnterCount, 1)
        XCTAssertEqual(country.callbacks.aroundUpdateExitCount, 0) // last update has failed
        XCTAssertEqual(country.callbacks.didUpdateCount, 0)        // last update has failed
        
        XCTAssertEqual(country.callbacks.willSaveCount, 1)
        XCTAssertEqual(country.callbacks.aroundSaveEnterCount, 1)
        XCTAssertEqual(country.callbacks.aroundSaveExitCount, 0) // last update has failed
        XCTAssertEqual(country.callbacks.didSaveCount, 0)        // last update has failed
        
        XCTAssertEqual(country.callbacks.willDeleteCount, 0)
        XCTAssertEqual(country.callbacks.aroundDeleteEnterCount, 0)
        XCTAssertEqual(country.callbacks.aroundDeleteExitCount, 0)
        XCTAssertEqual(country.callbacks.didDeleteCount, 0)
    }
    
    func testSaveMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France")
            try country1.save(db)
            
            XCTAssertEqual(country1.callbacks.willInsertCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country1.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country1.callbacks.willUpdateCount, 1)
            XCTAssertEqual(country1.callbacks.aroundUpdateEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundUpdateExitCount, 0) // last update has failed
            XCTAssertEqual(country1.callbacks.didUpdateCount, 0)        // last update has failed
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 1)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 1)
            XCTAssertEqual(country1.callbacks.didSaveCount, 1)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 0)
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France")
            
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "US",
                name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            XCTAssertEqual(country1.callbacks.willInsertCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country1.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country1.callbacks.willUpdateCount, 2)
            XCTAssertEqual(country1.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(country1.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(country1.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 2)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 2)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(country1.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 0)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            _ = try country1.delete(db)
            try country1.save(db)
            
            XCTAssertEqual(country1.callbacks.willInsertCount, 2)
            XCTAssertEqual(country1.callbacks.aroundInsertEnterCount, 2)
            XCTAssertEqual(country1.callbacks.aroundInsertExitCount, 2)
            XCTAssertEqual(country1.callbacks.didInsertCount, 2)
            
            XCTAssertEqual(country1.callbacks.willUpdateCount, 3)
            XCTAssertEqual(country1.callbacks.aroundUpdateEnterCount, 3)
            XCTAssertEqual(country1.callbacks.aroundUpdateExitCount, 1) // last update has failed
            XCTAssertEqual(country1.callbacks.didUpdateCount, 1)        // last update has failed
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 3)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 3)
            XCTAssertEqual(country1.callbacks.didSaveCount, 3)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 1)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 1)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 1)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "United States")
            XCTAssertEqual(rows[1]["rowID"] as Int64, country1.rowID!)
            XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
        }
    }
    
    func testDeleteMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France")
            try country1.insert(db)
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "US",
                name: "United States")
            try country2.insert(db)
            
            var deleted = try country1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try country1.delete(db)
            XCTAssertFalse(deleted)
            
            XCTAssertEqual(country1.callbacks.willInsertCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country1.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country1.callbacks.willUpdateCount, 0)
            XCTAssertEqual(country1.callbacks.aroundUpdateEnterCount, 0)
            XCTAssertEqual(country1.callbacks.aroundUpdateExitCount, 0)
            XCTAssertEqual(country1.callbacks.didUpdateCount, 0)
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 1)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 1)
            XCTAssertEqual(country1.callbacks.didSaveCount, 1)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 2)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 2)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 2)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 2)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }
    
    func testExistsMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France")
            try country.insert(db)
            
            XCTAssertTrue(try country.exists(db))
            
            XCTAssertEqual(country.callbacks.willInsertCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country.callbacks.willUpdateCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateEnterCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateExitCount, 0)
            XCTAssertEqual(country.callbacks.didUpdateCount, 0)
            
            XCTAssertEqual(country.callbacks.willSaveCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveExitCount, 1)
            XCTAssertEqual(country.callbacks.didSaveCount, 1)
            
            XCTAssertEqual(country.callbacks.willDeleteCount, 0)
            XCTAssertEqual(country.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(country.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(country.callbacks.didDeleteCount, 0)
            
            _ = try country.delete(db)
            
            XCTAssertFalse(try country.exists(db))
            
            XCTAssertEqual(country.callbacks.willInsertCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(country.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(country.callbacks.willUpdateCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateEnterCount, 0)
            XCTAssertEqual(country.callbacks.aroundUpdateExitCount, 0)
            XCTAssertEqual(country.callbacks.didUpdateCount, 0)
            
            XCTAssertEqual(country.callbacks.willSaveCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundSaveExitCount, 1)
            XCTAssertEqual(country.callbacks.didSaveCount, 1)
            
            XCTAssertEqual(country.callbacks.willDeleteCount, 1)
            XCTAssertEqual(country.callbacks.aroundDeleteEnterCount, 1)
            XCTAssertEqual(country.callbacks.aroundDeleteExitCount, 1)
            XCTAssertEqual(country.callbacks.didDeleteCount, 1)
        }
    }
    
    // MARK: - Misc
    
    func testPartiallyEncodedRecord() throws {
        struct PartialRecord : MutablePersistableRecord {
            var id: Int64?
            var a: String
            
            static let databaseTableName = "records"
            
            func encode(to container: inout PersistenceContainer) {
                container["id"] = id
                container["a"] = a
            }
            
            mutating func didInsert(_ inserted: InsertionSuccess) {
                id = inserted.rowID
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text)
                t.column("c", .integer).notNull().defaults(to: 123)
            }
            
            // Insertion only inserts defined columns
            var record = PartialRecord(id: nil, a: "foo")
            try record.insert(db)
            XCTAssertTrue(
                ["INSERT INTO \"records\" (\"id\", \"a\") VALUES (NULL,'foo')",
                 "INSERT INTO \"records\" (\"a\", \"id\") VALUES ('foo',NULL)"]
                    .contains(lastSQLQuery))
            XCTAssertEqual(try Row.fetchOne(db, sql: "SELECT * FROM records")!, ["id": 1, "a": "foo", "b": nil, "c": 123])
            
            // Update only updates defined columns
            record.a = "bar"
            try record.update(db)
            XCTAssertEqual(lastSQLQuery, "UPDATE \"records\" SET \"a\"='bar' WHERE \"id\"=1")
            XCTAssertEqual(try Row.fetchOne(db, sql: "SELECT * FROM records")!, ["id": 1, "a": "bar", "b": nil, "c": 123])
            
            // Update always update something
            record.a = "baz"
            try record.update(db, columns: ["b"])
            XCTAssertEqual(lastSQLQuery, "UPDATE \"records\" SET \"id\"=1 WHERE \"id\"=1")
            XCTAssertEqual(try Row.fetchOne(db, sql: "SELECT * FROM records")!, ["id": 1, "a": "bar", "b": nil, "c": 123])
            
            // Deletion
            try record.delete(db)
            XCTAssertEqual(lastSQLQuery, "DELETE FROM \"records\" WHERE \"id\"=1")
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM records")!, 0)
            
            // Expect database errors when missing columns must have a value
            try db.drop(table: "records")
            try db.create(table: "records") { t in
                t.primaryKey("id", .integer)
                t.column("a", .text)
                t.column("b", .text).notNull()
            }
            do {
                try record.insert(db)
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                // actual error message depends on the SQLite version
                XCTAssertTrue(
                    ["NOT NULL constraint failed: records.b",
                     "records.b may not be NULL"].contains(error.message!))
            }
        }
    }
    
    func testRecordErrorRecordNotFoundDescription() {
        do {
            let error = RecordError.recordNotFound(
                databaseTableName: "place",
                key: ["id": .null])
            XCTAssertEqual(
                error.description,
                "Key not found in table place: [id:NULL]")
        }
        do {
            let error = RecordError.recordNotFound(
                databaseTableName: "user",
                key: ["uuid": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".databaseValue])
            XCTAssertEqual(
                error.description,
                "Key not found in table user: [uuid:\"E621E1F8-C36C-495A-93FC-0C247A3E6E5F\"]")
        }
    }
    
    func testGeneratedColumnsInsertIsAnError() throws {
#if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
#else
        struct T: MutablePersistableRecord {
            func encode(to container: inout PersistenceContainer) {
                container["a"] = 1
                container["b"] = 1
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t (a, b ALWAYS GENERATED AS (a))")
            do {
                var record = T()
                try record.insert(db)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "cannot INSERT into generated column \"b\"")
                XCTAssertEqual(error.sql!, "INSERT INTO \"t\" (\"a\", \"b\") VALUES (?,?)")
            }
        }
#endif
    }
    
    func testGeneratedColumnsUpdateIsAnError() throws {
#if !GRDBCUSTOMSQLITE
        throw XCTSkip("Generated columns are not available")
#else
        struct T: MutablePersistableRecord {
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
                container["a"] = 1
            }
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: "CREATE TABLE t (id INTEGER PRIMARY KEY, a ALWAYS GENERATED AS (id))")
            do {
                try T().update(db)
                XCTFail("Expected error")
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_ERROR)
                XCTAssertEqual(error.message!, "cannot UPDATE generated column \"a\"")
                XCTAssertEqual(error.sql!, "UPDATE \"t\" SET \"a\"=? WHERE \"id\"=?")
            }
        }
#endif
    }
}

// MARK: - Insert and Fetch

extension MutablePersistableRecordTests {
    func test_insertAndFetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = FullPlayer(id: nil, name: "Arthur", score: 1000)
            let insertedPlayer = try player.insertAndFetch(db)
            XCTAssertEqual(insertedPlayer.id, 1)
            XCTAssertEqual(insertedPlayer.name, "Arthur")
            XCTAssertEqual(insertedPlayer.score, 1000)
        }
    }
    
    func test_insertAndFetch_as() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.insertAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(fullPlayer.id, 1)
                XCTAssertEqual(fullPlayer.name, "Arthur")
                XCTAssertEqual(fullPlayer.score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
        }
    }
    
    func test_insertAndFetch_selection_fetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(name: "Arthur")
                let score = try partialPlayer.insertAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)!
                }
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }

            do {
                // Test onConflict: .ignore
                clearSQLQueries()
                var player = FullPlayer(id: 1, name: "Barbara", score: 100)
                try XCTAssertTrue(player.exists(db))
                let score = try player.insertAndFetch(db, onConflict: .ignore, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.contains("""
                    INSERT OR IGNORE INTO "player" ("id", "name", "score") VALUES (1,'Barbara',100) RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(player.id, 1)
                XCTAssertNil(score)
                
                XCTAssertEqual(player.callbacks.willInsertCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(player.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(player.callbacks.willUpdateCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(player.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(player.callbacks.willSaveCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(player.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(player.callbacks.willDeleteCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(player.callbacks.didDeleteCount, 0)
            }
        }
    }
}

// MARK: - Save and Fetch

extension MutablePersistableRecordTests {
    func test_saveAndFetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let player = FullPlayer(id: nil, name: "Arthur", score: 1000)
            let savedPlayer = try player.saveAndFetch(db)
            XCTAssertEqual(savedPlayer.id, 1)
            XCTAssertEqual(savedPlayer.name, "Arthur")
            XCTAssertEqual(savedPlayer.score, 1000)
        }
    }
    
    func test_saveAndFetch_as() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(fullPlayer.id, 1)
                XCTAssertEqual(fullPlayer.name, "Arthur")
                XCTAssertEqual(fullPlayer.score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
            
            do {
                var partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                try partialPlayer.delete(db)
                clearSQLQueries()
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (1,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(fullPlayer.id, 1)
                XCTAssertEqual(fullPlayer.name, "Arthur")
                XCTAssertEqual(fullPlayer.score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 1)
            }
            
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(fullPlayer.id, 1)
                XCTAssertEqual(fullPlayer.name, "Arthur")
                XCTAssertEqual(fullPlayer.score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
        }
    }
    
    func test_saveAndFetch_selection_fetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(name: "Arthur")
                let score = try partialPlayer.saveAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
            
            do {
                var partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                try partialPlayer.delete(db)
                clearSQLQueries()
                let score = try partialPlayer.saveAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (1,'Arthur') RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 1)
            }
            
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let score = try partialPlayer.saveAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
        }
    }
}

// MARK: - Update and Fetch

extension MutablePersistableRecordTests {
    func test_updateAndFetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateAndFetch(db)
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            player.name = "Barbara"
            
            do {
                let updatedPlayer = try player.updateAndFetch(db)
                XCTAssertEqual(updatedPlayer.id, 1)
                XCTAssertEqual(updatedPlayer.name, "Barbara")
                XCTAssertEqual(updatedPlayer.score, 1000)
            }
            
            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateAndFetch_as() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateAndFetch(db, as: PartialPlayer.self)
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            player.name = "Barbara"
            
            do {
                let updatedPlayer = try player.updateAndFetch(db, as: PartialPlayer.self)
                XCTAssertEqual(updatedPlayer.id, 1)
                XCTAssertEqual(updatedPlayer.name, "Barbara")
            }
            
            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateAndFetch_selection_fetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateAndFetch(db, selection: [.allColumns]) { statement in
                    try Row.fetchOne(statement)
                }
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            player.name = "Barbara"
            player.score = 0

            do {
                let row = try player.updateAndFetch(db, selection: [.allColumns]) { statement in
                    try Row.fetchOne(statement)
                }
                XCTAssertEqual(row, ["id": 1, "name": "Barbara", "score": 0])
            }
            
            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateAndFetch_columns_selection_fetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateAndFetch(db, columns: [Column("score")], selection: [.allColumns]) { statement in
                    try Row.fetchOne(statement)
                }
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            player.name = "Barbara"
            player.score = 0

            do {
                let row = try player.updateAndFetch(db, columns: [Column("score")], selection: [.allColumns]) { statement in
                    try Row.fetchOne(statement)
                }
                XCTAssertEqual(row, ["id": 1, "name": "Arthur", "score": 0])
            }
            
            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateChangesAndFetch_modify() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateChangesAndFetch(db) {
                    $0.name = "Barbara"
                }
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            
            do {
                let updatedPlayer = try player.updateChangesAndFetch(db) {
                    $0.name = "Barbara"
                }
                XCTAssertNil(updatedPlayer)
            }
            
            do {
                let updatedPlayer = try XCTUnwrap(player.updateChangesAndFetch(db) {
                    $0.name = "Craig"
                })
                XCTAssertEqual(updatedPlayer.id, 1)
                XCTAssertEqual(updatedPlayer.name, "Craig")
                XCTAssertEqual(updatedPlayer.score, 1000)
            }

            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateChangesAndFetch_as_modify() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateChangesAndFetch(db, as: PartialPlayer.self) {
                    $0.name = "Barbara"
                }
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            
            do {
                let updatedPlayer = try player.updateChangesAndFetch(db, as: PartialPlayer.self) {
                    $0.name = "Barbara"
                }
                XCTAssertNil(updatedPlayer)
            }
            
            do {
                let updatedPlayer = try XCTUnwrap(player.updateChangesAndFetch(db, as: PartialPlayer.self) {
                    $0.name = "Craig"
                })
                XCTAssertEqual(updatedPlayer.id, 1)
                XCTAssertEqual(updatedPlayer.name, "Craig")
            }

            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
    
    func test_updateChangesAndFetch_selection_fetch_modify() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
            do {
                _ = try player.updateChangesAndFetch(
                    db, selection: [.allColumns],
                    fetch: { statement in try Row.fetchOne(statement) },
                    modify: { $0.name = "Barbara" })
                XCTFail("Expected RecordError")
            } catch RecordError.recordNotFound(databaseTableName: "player", key: ["id": 1.databaseValue]) { }
            
            try player.insert(db)
            
            do {
                // Update with no change
                let update = try player.updateChangesAndFetch(
                    db, selection: [.allColumns],
                    fetch: { statement in
                        XCTFail("Should not be called")
                        return "ignored"
                    },
                    modify: { $0.name = "Barbara" })
                XCTAssertNil(update)
            }
            
            do {
                let updatedRow = try player.updateChangesAndFetch(
                    db, selection: [.allColumns],
                    fetch: { statement in try Row.fetchOne(statement) },
                    modify: { $0.name = "Craig" })
                XCTAssertEqual(updatedRow, ["id": 1, "name": "Craig", "score": 1000])
            }

            XCTAssertEqual(player.callbacks.willInsertCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
            XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
            XCTAssertEqual(player.callbacks.didInsertCount, 1)
            
            XCTAssertEqual(player.callbacks.willUpdateCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 2)
            XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 1)
            XCTAssertEqual(player.callbacks.didUpdateCount, 1)
            
            XCTAssertEqual(player.callbacks.willSaveCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(player.callbacks.aroundSaveExitCount, 2)
            XCTAssertEqual(player.callbacks.didSaveCount, 2)
            
            XCTAssertEqual(player.callbacks.willDeleteCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
            XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
            XCTAssertEqual(player.callbacks.didDeleteCount, 0)
        }
    }
}

// MARK: - Upsert

extension MutablePersistableRecordTests {
    func test_upsert() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            do {
                var player = FullPlayer(name: "Arthur", score: 1000)
                try player.upsert(db)
                
                // Test SQL
                XCTAssertEqual(lastSQLQuery, """
                    INSERT INTO "player" ("id", "name", "score") \
                    VALUES (NULL,'Arthur',1000) \
                    ON CONFLICT DO UPDATE SET "name" = "excluded"."name", "score" = "excluded"."score" \
                    RETURNING "rowid"
                    """)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Arthur", "score":1000],
                ])
                
                // Test didSave callback
                XCTAssertEqual(player.id, 1)
                
                // Test other callbacks
                XCTAssertEqual(player.callbacks.willInsertCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(player.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(player.callbacks.willUpdateCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(player.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(player.callbacks.willSaveCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(player.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(player.callbacks.willDeleteCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(player.callbacks.didDeleteCount, 0)
            }
            
            // Test conflict on name
            do {
                // Set the last inserted row id to some arbitrary value
                _ = try FullPlayer(id: 42, name: "Barbara", score: 0).inserted(db)
                XCTAssertNotEqual(db.lastInsertedRowID, 1)
                
                var player = FullPlayer(name: "Arthur", score: 100)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Arthur", "score":100],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
                
                // Test didSave callback
                XCTAssertEqual(player.id, 1)
            }
            
            // Test conflict on id
            do {
                var player = FullPlayer(id: 1, name: "Craig", score: 500)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Craig", "score":500],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
                
                // Test didSave callback
                XCTAssertEqual(player.id, 1)
            }
            
            // Test conflict on both id and name (same row)
            do {
                var player = FullPlayer(id: 1, name: "Craig", score: 200)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Craig", "score":200],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
                
                // Test didSave callback
                XCTAssertEqual(player.id, 1)
            }
            
            // Test conflict on both id and name (different rows)
            do {
                var player = FullPlayer(id: 1, name: "Barbara", score: 300)
                
                do {
                    try player.upsert(db)
                    XCTFail("Expected error")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
                    XCTAssertEqual(error.message, "UNIQUE constraint failed: player.name")
                    XCTAssertEqual(error.sql!, """
                        INSERT INTO "player" ("id", "name", "score") \
                        VALUES (?,?,?) \
                        ON CONFLICT DO UPDATE SET "name" = "excluded"."name", "score" = "excluded"."score" \
                        RETURNING "rowid"
                        """)
                }
                
                // Test callbacks
                XCTAssertEqual(player.callbacks.willInsertCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertExitCount, 0)
                XCTAssertEqual(player.callbacks.didInsertCount, 0)
                
                XCTAssertEqual(player.callbacks.willUpdateCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(player.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(player.callbacks.willSaveCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveExitCount, 0)
                XCTAssertEqual(player.callbacks.didSaveCount, 0)
                
                XCTAssertEqual(player.callbacks.willDeleteCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(player.callbacks.didDeleteCount, 0)
            }
        }
    }

    func test_upsertAndFetch_do_update_set_where() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        try makeDatabaseQueue().write { db in
            // Test exemples of https://www.sqlite.org/lang_UPSERT.html
            do {
                try db.execute(sql: """
                    CREATE TABLE vocabulary(
                      word TEXT PRIMARY KEY,
                      kind TEXT,
                      isTainted BOOLEAN DEFAULT 0,
                      count INT DEFAULT 1);
                    INSERT INTO vocabulary(word, isTainted) VALUES('jovial', 1);
                    """)
                
                struct Vocabulary: Decodable, MutablePersistableRecord, FetchableRecord {
                    var word: String
                    var kind: String
                    var isTainted: Bool
                    var count: Int?
                    var rowID: Int64?
                    
                    func encode(to container: inout PersistenceContainer) {
                        // Don't encode count and rowID
                        container["word"] = word
                        container["kind"] = kind
                        container["isTainted"] = isTainted
                    }
                    
                    mutating func didInsert(_ inserted: InsertionSuccess) {
                        rowID = inserted.rowID
                    }
                }
                
                // One column with specific assignment (count)
                // One column with no assignment (isTainted)
                // One column with default overwrite assignment (kind)
                do {
                    var vocabulary = Vocabulary(word: "jovial", kind: "adjective", isTainted: false)
                    let upserted = try vocabulary.upsertAndFetch(
                        db, onConflict: ["word"],
                        doUpdate: { _ in
                            [Column("count") += 1,             // increment count
                             Column("isTainted").noOverwrite] // don't overwrite isTainted
                        })
                    
                    // Test didSave
                    XCTAssertEqual(vocabulary.rowID, 1)
                    
                    // Test SQL
                    XCTAssertEqual(lastSQLQuery, """
                        INSERT INTO "vocabulary" ("word", "kind", "isTainted") \
                        VALUES ('jovial','adjective',0) \
                        ON CONFLICT("word") \
                        DO UPDATE SET "count" = "count" + 1, "kind" = "excluded"."kind" \
                        RETURNING *, "rowid"
                        """)
                    
                    // Test database state
                    let rows = try Row.fetchAll(db, sql: "SELECT * FROM vocabulary")
                    XCTAssertEqual(rows, [
                        ["word": "jovial", "kind": "adjective", "isTainted": 1, "count": 2],
                    ])
                    
                    // Test upserted record
                    XCTAssertEqual(upserted.word, "jovial")
                    XCTAssertEqual(upserted.kind, "adjective")
                    XCTAssertEqual(upserted.isTainted, true)   // Not overwritten
                    XCTAssertEqual(upserted.count, 2)          // incremented
                }
                
                // All columns with no assignment: make sure we return something
                do {
                    var vocabulary = Vocabulary(word: "jovial", kind: "ignored", isTainted: false)
                    let upserted = try vocabulary.upsertAndFetch(
                        db, onConflict: ["word"],
                        doUpdate: { _ in
                            [Column("count").noOverwrite,
                             Column("isTainted").noOverwrite,
                             Column("kind").noOverwrite]
                        })
                    
                    // Test didSave
                    XCTAssertEqual(vocabulary.rowID, 1)
                    
                    // Test SQL (the DO UPDATE clause is not empty, so that the
                    // RETURNING clause could return something).
                    XCTAssertEqual(lastSQLQuery, """
                        INSERT INTO "vocabulary" ("word", "kind", "isTainted") \
                        VALUES ('jovial','ignored',0) \
                        ON CONFLICT("word") \
                        DO UPDATE SET "word" = "word" \
                        RETURNING *, "rowid"
                        """)
                    
                    // Test database state
                    let rows = try Row.fetchAll(db, sql: "SELECT * FROM vocabulary")
                    XCTAssertEqual(rows, [
                        ["word": "jovial", "kind": "adjective", "isTainted": 1, "count": 2],
                    ])
                    
                    // Test upserted record
                    XCTAssertEqual(upserted.word, "jovial")
                    XCTAssertEqual(upserted.kind, "adjective")
                    XCTAssertEqual(upserted.isTainted, true)
                    XCTAssertEqual(upserted.count, 2)
                }
            }
            
            do {
                try db.execute(sql: """
                    CREATE TABLE phonebook(name TEXT PRIMARY KEY, phonenumber TEXT);
                    INSERT INTO phonebook(name,phonenumber) VALUES('Alice','ignored');
                    """)
                
                struct Phonebook: Codable, MutablePersistableRecord, FetchableRecord {
                    var name: String
                    var phonenumber: String
                }
                
                var phonebook = Phonebook(name: "Alice", phonenumber: "704-555-1212")
                let upserted = try phonebook.upsertAndFetch(
                    db, onConflict: ["name"],
                    doUpdate: { excluded in
                        [Column("phonenumber").set(to: excluded["phonenumber"])]
                    })
                
                // Test SQL
                XCTAssertEqual(lastSQLQuery, """
                    INSERT INTO "phonebook" ("name", "phonenumber") \
                    VALUES ('Alice','704-555-1212') \
                    ON CONFLICT("name") DO UPDATE SET "phonenumber" = "excluded"."phonenumber" \
                    RETURNING *, "rowid"
                    """)
                
                // Test database state
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM phonebook")
                XCTAssertEqual(rows, [
                    ["name": "Alice", "phonenumber": "704-555-1212"],
                ])
                
                // Test upserted record
                XCTAssertEqual(upserted.name, "Alice")
                XCTAssertEqual(upserted.phonenumber, "704-555-1212")
            }
        }
    }
    
    func test_upsertAndFetch() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var player = FullPlayer(id: 1, name: "Arthur", score: 1000)
                let upsertedPlayer = try player.upsertAndFetch(db)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name", "score") \
                    VALUES (1,'Arthur',1000) \
                    ON CONFLICT DO UPDATE SET "name" = "excluded"."name", "score" = "excluded"."score" \
                    RETURNING *, "rowid"
                    """), sqlQueries.joined(separator: "\n"))
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Arthur", "score":1000],
                ])
                
                XCTAssertEqual(player.id, 1)
                XCTAssertEqual(upsertedPlayer.id, 1)
                XCTAssertEqual(upsertedPlayer.name, "Arthur")
                XCTAssertEqual(upsertedPlayer.score, 1000)
                
                XCTAssertEqual(player.callbacks.willInsertCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(player.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(player.callbacks.willUpdateCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(player.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(player.callbacks.willSaveCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(player.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(player.callbacks.willDeleteCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(player.callbacks.didDeleteCount, 0)
            }
            
            do {
                clearSQLQueries()
                var player = FullPlayer(id: 1, name: "Barbara", score: 100)
                let upsertedPlayer = try player.upsertAndFetch(db)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name", "score") \
                    VALUES (1,'Barbara',100) \
                    ON CONFLICT DO UPDATE SET "name" = "excluded"."name", "score" = "excluded"."score" \
                    RETURNING *, "rowid"
                    """), sqlQueries.joined(separator: "\n"))

                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Barbara", "score":100],
                ])
                
                XCTAssertEqual(player.id, 1)
                XCTAssertEqual(upsertedPlayer.id, 1)
                XCTAssertEqual(upsertedPlayer.name, "Barbara")
                XCTAssertEqual(upsertedPlayer.score, 100)
                
                XCTAssertEqual(player.callbacks.willInsertCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(player.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(player.callbacks.willUpdateCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(player.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(player.callbacks.willSaveCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(player.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(player.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(player.callbacks.willDeleteCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(player.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(player.callbacks.didDeleteCount, 0)
            }
        }
    }

    func test_upsertAndFetch_as() throws {
#if GRDBCUSTOMSQLITE || GRDBCIPHER
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("UPSERT is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("UPSERT is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                clearSQLQueries()
                var partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.upsertAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") \
                    VALUES (NULL,'Arthur') \
                    ON CONFLICT DO UPDATE SET "name" = "excluded"."name" \
                    RETURNING *, "rowid"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(partialPlayer.id, 1)
                XCTAssertEqual(fullPlayer.id, 1)
                XCTAssertEqual(fullPlayer.name, "Arthur")
                XCTAssertEqual(fullPlayer.score, 1000)
                
                XCTAssertEqual(partialPlayer.callbacks.willInsertCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundInsertExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didInsertCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willUpdateCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundUpdateExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didUpdateCount, 0)
                
                XCTAssertEqual(partialPlayer.callbacks.willSaveCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveEnterCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.aroundSaveExitCount, 1)
                XCTAssertEqual(partialPlayer.callbacks.didSaveCount, 1)
                
                XCTAssertEqual(partialPlayer.callbacks.willDeleteCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteEnterCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.aroundDeleteExitCount, 0)
                XCTAssertEqual(partialPlayer.callbacks.didDeleteCount, 0)
            }
        }
    }
}

// MARK: - Callback Misuse

extension MutablePersistableRecordTests {
    func test_aroundSave_misuse_by_not_calling_the_action() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
                // It is a programmer error to not call the `save` argument
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                try BadRecord().update(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundSave_misuse_by_not_rethrowing_the_action_error() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundSave(_ db: Database, save: () throws -> PersistenceSuccess) throws {
                // It is a programmer error to not rethrow the error of the `save` argument
                _ = try? save()
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                // Fails because we can't update anything
                try BadRecord().update(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundUpdate_misuse_by_not_calling_the_action() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
                // It is a programmer error to not call the `update` argument
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                try BadRecord().update(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundUpdate_misuse_by_not_rethrowing_the_action_error() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundUpdate(_ db: Database, columns: Set<String>, update: () throws -> PersistenceSuccess) throws {
                // It is a programmer error to not rethrow the error of the `update` argument
                _ = try? update()
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                // Fails because we can't update anything
                try BadRecord().update(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundInsert_misuse_by_not_calling_the_action() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
                // It is a programmer error to not call the `insert` argument
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                var record = BadRecord()
                try record.insert(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundInsert_misuse_by_not_rethrowing_the_action_error() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
                // It is a programmer error to not rethrow the error of the `insert` argument
                _ = try? insert()
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: """
                    CREATE TABLE badRecord(id INTEGER PRIMARY KEY);
                    INSERT INTO badRecord (id) VALUES (1);
                    """)
                var record = BadRecord()
                // Fails because we insert a conflict
                try record.insert(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundDelete_misuse_by_not_calling_the_action() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
                // It is a programmer error to not call the `delete` argument
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: "CREATE TABLE badRecord(a)")
                try BadRecord().delete(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
    
    func test_aroundDelete_misuse_by_not_rethrowing_the_action_error() throws {
        struct BadRecord: MutablePersistableRecord, Encodable {
            let id = 1
            func aroundDelete(_ db: Database, delete: () throws -> Bool) throws {
                // It is a programmer error to not rethrow the error of the `delete` argument
                _ = try? delete()
            }
        }
        do {
            try makeDatabaseQueue().write { db in
                try db.execute(sql: """
                    CREATE TABLE badRecord(id INTEGER PRIMARY KEY);
                    CREATE TABLE child(id INTEGER PRIMARY KEY REFERENCES badRecord(id) ON DELETE RESTRICT);
                    INSERT INTO badRecord (id) VALUES (1);
                    INSERT INTO child (id) VALUES (1);
                    """)
                // Fails because this deletion violates a constraint
                try BadRecord().delete(db)
                XCTFail("Expected SQLITE_MISUSE error")
            }
        } catch DatabaseError.SQLITE_MISUSE { }
    }
}
