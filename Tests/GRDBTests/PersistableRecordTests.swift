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
    
    func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
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

private struct PersistableRecordCustomizedCountry : PersistableRecord {
    var isoCode: String
    var name: String
    let willInsert: () -> Void
    let willUpdate: () -> Void
    let willSave: () -> Void
    let willDelete: () -> Void
    let willExists: () -> Void
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
    }
    
    func insert(_ db: Database) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(_ db: Database, columns: Set<String>) throws {
        willUpdate()
        try performUpdate(db, columns: columns)
    }
    
    func save(_ db: Database) throws {
        willSave()
        try performSave(db)
    }
    
    func delete(_ db: Database) throws -> Bool {
        willDelete()
        return try performDelete(db)
    }
    
    func exists(_ db: Database) throws -> Bool {
        willExists()
        return try performExists(db)
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

class PersistableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
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
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }

    func testSavePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistableRecordPerson(name: "Arthur", age: 42)
            try person.save(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
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
                try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
                try XCTAssertEqual(rows[0]["age"] as Int, 24)
                try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                try XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                person1.name = "Craig"
                person1.age = 25
                try person1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"name\"='Craig' WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                try XCTAssertEqual(rows[0]["name"] as String, "Craig")
                try XCTAssertEqual(rows[0]["age"] as Int, 24)
                try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                try XCTAssertEqual(rows[1]["age"] as Int, 36)
            }
            
            do {
                person1.name = "David"
                try person1.update(db, columns: ["AgE"])    // case insensitivity
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"age\"=25 WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
                try XCTAssertEqual(rows[0]["name"] as String, "Craig")
                try XCTAssertEqual(rows[0]["age"] as Int, 25)
                try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
                try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
                try XCTAssertEqual(rows[1]["age"] as Int, 36)
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            let person2 = PersistableRecordPersonClass(id: nil, name: "Barbara", age: 39)
            try person2.save(db)
            
            person1.name = "Craig"
            try person1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            
            try person1.delete(db)
            try person1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Barbara")
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
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France")
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
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
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
                try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
                try XCTAssertEqual(rows[0]["name"] as String, "France")
                try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
                try XCTAssertEqual(rows[1]["name"] as String, "United States")
            }
            
            do {
                country1.name = "France Métropolitaine"
                try country1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
                
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
                try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
                try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
                try XCTAssertEqual(rows[1]["name"] as String, "United States")
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
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = PersistableRecordCountry(isoCode: "US", name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
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
            try XCTAssertEqual(rows[0]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
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
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country.insert(db)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }

    func testUpdatePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db)
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 1)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }

    func testPartialUpdatePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db, columns: ["name"])
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 1)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }

    func testSavePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.save(db)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 1)
            XCTAssertEqual(saveCount, 1)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = PersistableRecordCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 2)
            XCTAssertEqual(saveCount, 2)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            _ = try country1.delete(db)
            try country1.save(db)
            
            XCTAssertEqual(insertCount, 2)
            XCTAssertEqual(updateCount, 3)
            XCTAssertEqual(saveCount, 3)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 0)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "FR")
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }

    func testDeletePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country1 = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableRecordCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.insert(db)
            
            var deleted = try country1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try country1.delete(db)
            XCTAssertFalse(deleted)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 2)
            XCTAssertEqual(existsCount, 0)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["isoCode"] as String, "US")
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }

    func testExistsPersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country = PersistableRecordCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country.insert(db)
            
            XCTAssertTrue(try country.exists(db))
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 1)
            
            _ = try country.delete(db)
            
            XCTAssertFalse(try country.exists(db))
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 2)
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
