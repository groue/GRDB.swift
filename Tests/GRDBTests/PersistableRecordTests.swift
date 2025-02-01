import XCTest
import GRDB

private struct PersistableRecordPerson : PersistableRecord {
    var name: String?
    var age: Int?
    
    static let databaseTableName = "persons"
    
    func encode(to container: inout PersistenceContainer) {
        container["name"] = name
        container["age"] = age
    }
}

private class PersistableRecordPersonClass : PersistableRecord {
    var id: Int64?
    var name: String?
    var age: Int?
    
    init(id: Int64?, name: String?, age: Int?) {
        self.id = id
        self.name = name
        self.age = age
    }
    
    static let databaseTableName = "persons"
    
    func encode(to container: inout PersistenceContainer) {
        // mangle case
        container["ID"] = id
        container["naME"] = name
        container["Age"] = age
    }
    
    func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

private struct PersistableRecordCountry : PersistableRecord {
    var isoCode: String
    var name: String
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
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

private struct PersistableRecordCustomizedCountry : PersistableRecord {
    var isoCode: String
    var name: String
    let callbacks = Callbacks()
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
    }
    
    func willInsert(_ db: Database) throws {
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
    
    func didInsert(_ inserted: InsertionSuccess) {
        callbacks.didInsertCount += 1
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

private struct Citizenship : PersistableRecord {
    let personID: Int64
    let countryIsoCode: String
    
    static let databaseTableName = "citizenships"
    
    func encode(to container: inout PersistenceContainer) {
        container["countryIsoCode"] = countryIsoCode
        container["personID"] = personID
    }
}

private struct PartialPlayer: Codable, PersistableRecord, FetchableRecord {
    static let databaseTableName = "player"
    let callbacks = Callbacks()
    var id: Int64?
    var name: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
    }
    
    func willInsert(_ db: Database) throws {
        callbacks.willInsertCount += 1
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        callbacks.aroundInsertEnterCount += 1
        _ = try insert()
        callbacks.aroundInsertExitCount += 1
    }
    
    func didInsert(_ inserted: InsertionSuccess) {
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

private struct FullPlayer: Codable, PersistableRecord, FetchableRecord {
    static let databaseTableName = "player"
    var id: Int64?
    var name: String
    var score: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, score
    }
    
    let callbacks = Callbacks()
    
    func willInsert(_ db: Database) throws {
        callbacks.willInsertCount += 1
    }
    
    func aroundInsert(_ db: Database, insert: () throws -> InsertionSuccess) throws {
        callbacks.aroundInsertEnterCount += 1
        _ = try insert()
        callbacks.aroundInsertExitCount += 1
    }
    
    func didInsert(_ inserted: InsertionSuccess) {
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

class PersistableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(sql: """
                CREATE TABLE persons (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    age INT NOT NULL);
                CREATE TABLE countries (
                    isoCode TEXT NOT NULL PRIMARY KEY,
                    name TEXT NOT NULL);
                CREATE TABLE citizenships (
                    countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode),
                    personID INTEGER NOT NULL REFERENCES persons(id));
                CREATE TABLE player(
                    id INTEGER PRIMARY KEY,
                    name NOT NULL UNIQUE, -- UNIQUE for upsert tests
                    score INTEGER NOT NULL DEFAULT 1000);
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    // MARK: - PersistableRecordPerson
    
    func testInsertPersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPerson(name: "Arthur", age: 42)
            try person.insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    func testSavePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPerson(name: "Arthur", age: 42)
            try person.save(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    // MARK: - PersistableRecordPersonClass
    
    func testInsertPersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    func testUpdatePersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(db)
            let person2 = PersistableRecordPersonClass(id: nil, name: "Barbara", age: 39)
            try person2.insert(db)
            
            person1.name = "Craig"
            try person1.update(db)
            XCTAssertTrue([
                "UPDATE \"persons\" SET \"age\"=42, \"name\"='Craig' WHERE \"id\"=1",
                "UPDATE \"persons\" SET \"name\"='Craig', \"age\"=42 WHERE \"id\"=1"
            ].contains(self.lastSQLQuery))
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Craig")
            XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            XCTAssertEqual(rows[1]["name"] as String, "Barbara")
        }
    }
    
    func testPartialUpdatePersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 24)
            try person1.insert(db)
            let person2 = PersistableRecordPersonClass(id: nil, name: "Barbara", age: 36)
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
    
    func testSavePersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 42)
            try person1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            let person2 = PersistableRecordPersonClass(id: nil, name: "Barbara", age: 39)
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
    
    func testDeletePersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(db)
            let person2 = PersistableRecordPersonClass(id: nil, name: "Barbara", age: 39)
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
    
    func testExistsPersistableRecordPersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(db)
            XCTAssertTrue(try person.exists(db))
            
            try person.delete(db)
            XCTAssertFalse(try person.exists(db))
        }
    }
    
    // MARK: - PersistableRecordCountry
    
    func testInsertPersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country.insert(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testUpdatePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db)
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testPartialUpdatePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            do {
                country1.name = "France Métropolitaine"
                try country1.update(db, columns: [String]())
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"isoCode\"='FR' WHERE \"isoCode\"='FR'")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
                XCTAssertEqual(rows[0]["name"] as String, "France")
                XCTAssertEqual(rows[1]["isoCode"] as String, "US")
                XCTAssertEqual(rows[1]["name"] as String, "United States")
            }
            
            do {
                country1.name = "France Métropolitaine"
                try country1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
                XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
                XCTAssertEqual(rows[1]["isoCode"] as String, "US")
                XCTAssertEqual(rows[1]["name"] as String, "United States")
            }
        }
    }
    
    func testSavePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = PersistableRecordCountry(isoCode: "US", name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testDeletePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country1 = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            var deleted = try country1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try country1.delete(db)
            XCTAssertFalse(deleted)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "US")
            XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }
    
    func testExistsPersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableRecordCountry(isoCode: "FR", name: "France")
            try country.insert(db)
            XCTAssertTrue(try country.exists(db))
            
            try country.delete(db)
            XCTAssertFalse(try country.exists(db))
        }
    }
    
    // MARK: - PersistableRecordCustomizedCountry
    
    func testInsertPersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableRecordCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testUpdatePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testRecordErrorPersistableRecordCustomizedCountry() throws {
        let country = PersistableRecordCustomizedCountry(
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
    
    func testPartialUpdatePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
                isoCode: "US",
                name: "United States")
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db, columns: ["name"])
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testSavePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableRecordCustomizedCountry(
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
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = PersistableRecordCustomizedCountry(
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
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
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
            XCTAssertEqual(country1.callbacks.didUpdateCount, 1)       // last update has failed
            
            XCTAssertEqual(country1.callbacks.willSaveCount, 3)
            XCTAssertEqual(country1.callbacks.aroundSaveEnterCount, 3)
            XCTAssertEqual(country1.callbacks.aroundSaveExitCount, 3)
            XCTAssertEqual(country1.callbacks.didSaveCount, 3)
            
            XCTAssertEqual(country1.callbacks.willDeleteCount, 1)
            XCTAssertEqual(country1.callbacks.aroundDeleteEnterCount, 1)
            XCTAssertEqual(country1.callbacks.aroundDeleteExitCount, 1)
            XCTAssertEqual(country1.callbacks.didDeleteCount, 1)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }
    
    func testDeletePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France")
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0]["isoCode"] as String, "US")
            XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }
    
    func testExistsPersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableRecordCustomizedCountry(
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
    
    // MARK: - Errors
    
    func testInsertErrorDoesNotPreventSubsequentInserts() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPersonClass(id: nil, name: "Arthur", age: 12)
            try person.insert(db)
            try PersistableRecordCountry(isoCode: "FR", name: "France").insert(db)
            do {
                try Citizenship(personID: person.id!, countryIsoCode: "US").insert(db)
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            }
            try Citizenship(personID: person.id!, countryIsoCode: "FR").insert(db)
        }
    }
}

// MARK: - Custom nested Codable types - nested saved as JSON

extension PersistableRecordTests {
    
    func testOptionalNestedStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: NestedStruct?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: nested)
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            XCTAssert(dbValue.storage.value is String)
            let string = dbValue.storage.value as! String
            if let data = string.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode(NestedStruct.self, from: data)
                    XCTAssertEqual(nested.firstName, decoded.firstName)
                    XCTAssertEqual(nested.lastName, decoded.lastName)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            } else {
                XCTFail("Failed to convert " + string)
            }
        }
    }
    
    func testOptionalNestedStructNil() throws {
        struct NestedStruct : Encodable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let nested: NestedStruct?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let value = StructWithNestedType(nested: nil)
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // We expect here nil
            XCTAssertNil(dbValue.storage.value)
        }
    }
    
    func testOptionalNestedArrayStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: [nested, nested])
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            XCTAssert(dbValue.storage.value is String)
            let string = dbValue.storage.value as! String
            if let data = string.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode([NestedStruct].self, from: data)
                    XCTAssertEqual(decoded.count, 2)
                    XCTAssertEqual(nested.firstName, decoded.first!.firstName)
                    XCTAssertEqual(nested.lastName, decoded.first!.lastName)
                    XCTAssertEqual(nested.firstName, decoded.last!.firstName)
                    XCTAssertEqual(nested.lastName, decoded.last!.lastName)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            } else {
                XCTFail("Failed to convert " + string)
            }
        }
    }
    
    func testOptionalNestedArrayStructNil() throws {
        struct NestedStruct : Encodable {
            let firstName: String?
            let lastName: String?
        }
        
        struct StructWithNestedType : PersistableRecord, Encodable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let value = StructWithNestedType(nested: nil)
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // We expect here nil
            XCTAssertNil(dbValue.storage.value)
        }
    }
    
    func testNonOptionalNestedStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String
            let lastName: String
        }
        
        struct StructWithNestedType : PersistableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: NestedStruct
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: nested)
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            XCTAssert(dbValue.storage.value is String)
            let string = dbValue.storage.value as! String
            if let data = string.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode(NestedStruct.self, from: data)
                    XCTAssertEqual(nested.firstName, decoded.firstName)
                    XCTAssertEqual(nested.lastName, decoded.lastName)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            } else {
                XCTFail("Failed to convert " + string)
            }
        }
    }
    
    func testNonOptionalNestedArrayStruct() throws {
        struct NestedStruct : Codable {
            let firstName: String
            let lastName: String
        }
        
        struct StructWithNestedType : PersistableRecord, Codable {
            static let databaseTableName = "t1"
            let nested: [NestedStruct]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("nested", .text)
            }
            
            let nested = NestedStruct(firstName: "Bob", lastName: "Dylan")
            let value = StructWithNestedType(nested: [nested])
            try value.insert(db)
            
            let dbValue = try DatabaseValue.fetchOne(db, sql: "SELECT nested FROM t1")!
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            XCTAssert(dbValue.storage.value is String)
            let string = dbValue.storage.value as! String
            if let data = string.data(using: .utf8) {
                do {
                    let decoded = try JSONDecoder().decode([NestedStruct].self, from: data)
                    XCTAssertEqual(nested.firstName, decoded.first!.firstName)
                    XCTAssertEqual(nested.lastName, decoded.first!.lastName)
                } catch {
                    XCTFail(error.localizedDescription)
                }
            } else {
                XCTFail("Failed to convert " + string)
            }
        }
    }
    
    func testStringStoredInArray() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let numbers: [String]
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("numbers", .text)
            }
            
            let model = TestStruct(numbers: ["test1", "test2", "test3"])
            try model.insert(db)
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            
            guard let fetchModel = try TestStruct.fetchOne(db) else {
                XCTFail("Could not find record in db")
                return
            }
            
            XCTAssertEqual(model.numbers, fetchModel.numbers)
        }
    }
    
    func testOptionalStringStoredInArray() throws {
        struct TestStruct : PersistableRecord, FetchableRecord, Codable {
            static let databaseTableName = "t1"
            let numbers: [String]?
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "t1") { t in
                t.column("numbers", .text)
            }
            
            let model = TestStruct(numbers: ["test1", "test2", "test3"])
            try model.insert(db)
            
            // Encodable has a default implementation which encodes a model to JSON as String.
            // We expect here JSON in the form of a String
            
            guard let fetchModel = try TestStruct.fetchOne(db) else {
                XCTFail("Could not find record in db")
                return
            }
            
            XCTAssertEqual(model.numbers, fetchModel.numbers)
        }
    }
    
}

// MARK: - Insert and Fetch

extension PersistableRecordTests {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.insertAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
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
    
    func test_insertAndFetch_selection_fetch_column() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let score = try partialPlayer.insertAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)!
                }
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
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
        }
    }
    
    func test_insertAndFetch_selection_fetch_allColumns() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let row = try partialPlayer.insertAndFetch(db, selection: [.allColumns]) { (statement: Statement) in
                    try Row.fetchOne(statement)!
                }
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur", "score": 1000])
                
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
    
    func test_insertAndFetch_selection_fetch_allColumns_excluding() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let row = try partialPlayer.insertAndFetch(db, selection: [.allColumns(excluding: ["score"])]) { (statement: Statement) in
                    try Row.fetchOne(statement)!
                }
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "id", "name"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
                
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

// MARK: - Save and Fetch

extension PersistableRecordTests {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                try partialPlayer.delete(db)
                clearSQLQueries()
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (1,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let fullPlayer = try partialPlayer.saveAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
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
    
    func test_saveAndFetch_selection_fetch_column() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let score = try partialPlayer.saveAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let score = try partialPlayer.saveAndFetch(db, selection: [Column("score")]) { (statement: Statement) in
                    try Int.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING "score"
                    """), sqlQueries.joined(separator: "\n"))
                
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
    
    func test_saveAndFetch_selection_fetch_allColumns() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns]) { (
                    statement: Statement
                ) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur", "score": 1000])
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                try partialPlayer.delete(db)
                clearSQLQueries()
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns]) { (statement: Statement) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (1,'Arthur') RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur", "score": 1000])
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns]) { (statement: Statement) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING *
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur", "score": 1000])
                
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
    
    func test_saveAndFetch_selection_fetch_allColumns_excluding() throws {
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns(excluding: ["score"])]) { (
                    statement: Statement
                ) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("UPDATE") })
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (NULL,'Arthur') RETURNING "id", "name"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                try partialPlayer.delete(db)
                clearSQLQueries()
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns(excluding: ["score"])]) { (statement: Statement) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING "id", "name"
                    """), sqlQueries.joined(separator: "\n"))
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") VALUES (1,'Arthur') RETURNING "id", "name"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
                
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
                let partialPlayer = PartialPlayer(id: 1, name: "Arthur")
                let row = try partialPlayer.saveAndFetch(db, selection: [.allColumns(excluding: ["score"])]) { (statement: Statement) in
                    try Row.fetchOne(statement)
                }
                
                XCTAssert(sqlQueries.allSatisfy { !$0.contains("INSERT") })
                XCTAssert(sqlQueries.contains("""
                    UPDATE "player" SET "name"='Arthur' WHERE "id"=1 RETURNING "id", "name"
                    """), sqlQueries.joined(separator: "\n"))
                
                XCTAssertEqual(row, ["id": 1, "name": "Arthur"])
                
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

// MARK: - Upsert

extension PersistableRecordTests {
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
                let player = FullPlayer(name: "Arthur", score: 1000)
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
                
                // Test callbacks
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
                
                let player = FullPlayer(name: "Arthur", score: 100)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Arthur", "score":100],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
            }
            
            // Test conflict on id
            do {
                let player = FullPlayer(id: 1, name: "Craig", score: 500)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Craig", "score":500],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
            }
            
            // Test conflict on both id and name (same row)
            do {
                let player = FullPlayer(id: 1, name: "Craig", score: 200)
                try player.upsert(db)
                
                // Test database state
                let rows = try Row.fetchAll(db, FullPlayer.orderByPrimaryKey())
                XCTAssertEqual(rows, [
                    ["id": 1, "name": "Craig", "score":200],
                    ["id": 42, "name": "Barbara", "score":0],
                ])
            }
            
            // Test conflict on both id and name (different rows)
            do {
                let player = FullPlayer(id: 1, name: "Barbara", score: 300)
                
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
                
                struct Vocabulary: Decodable, PersistableRecord, FetchableRecord {
                    var word: String
                    var kind: String
                    var isTainted: Bool
                    var count: Int?
                    
                    func encode(to container: inout PersistenceContainer) {
                        // Don't encode count
                        container["word"] = word
                        container["kind"] = kind
                        container["isTainted"] = isTainted
                    }
                }
                
                // One column with specific assignment (count)
                // One column with no assignment (isTainted)
                // One column with default overwrite assignment (kind)
                do {
                    let vocabulary = Vocabulary(word: "jovial", kind: "adjective", isTainted: false)
                    let upserted = try vocabulary.upsertAndFetch(
                        db, onConflict: ["word"],
                        doUpdate: { _ in
                            [Column("count") += 1,             // increment count
                             Column("isTainted").noOverwrite] // don't overwrite isTainted
                        })
                    
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
                    let vocabulary = Vocabulary(word: "jovial", kind: "ignored", isTainted: false)
                    let upserted = try vocabulary.upsertAndFetch(
                        db, onConflict: ["word"],
                        doUpdate: { _ in
                            [Column("count").noOverwrite,
                             Column("isTainted").noOverwrite,
                             Column("kind").noOverwrite]
                        })
                    
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
                
                struct Phonebook: Codable, PersistableRecord, FetchableRecord {
                    var name: String
                    var phonenumber: String
                }
                
                let phonebook = Phonebook(name: "Alice", phonenumber: "704-555-1212")
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
                let player = FullPlayer(id: 1, name: "Arthur", score: 1000)
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
                let player = FullPlayer(id: 1, name: "Barbara", score: 100)
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
                let partialPlayer = PartialPlayer(name: "Arthur")
                let fullPlayer = try partialPlayer.upsertAndFetch(db, as: FullPlayer.self)
                
                XCTAssert(sqlQueries.contains("""
                    INSERT INTO "player" ("id", "name") \
                    VALUES (NULL,'Arthur') \
                    ON CONFLICT DO UPDATE SET "name" = "excluded"."name" \
                    RETURNING *, "rowid"
                    """), sqlQueries.joined(separator: "\n"))
                
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
