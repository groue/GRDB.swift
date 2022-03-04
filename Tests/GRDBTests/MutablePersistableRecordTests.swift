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
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
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
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.rowID = rowID
    }
}

private struct MutablePersistableRecordCustomizedCountry : MutablePersistableRecord {
    var rowID: Int64?
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
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        self.rowID = rowID
    }
    
    mutating func insert(_ db: Database) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(_ db: Database, columns: Set<String>) throws {
        willUpdate()
        try performUpdate(db, columns: columns)
    }
    
    mutating func save(_ db: Database) throws {
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

class MutablePersistableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
        }
    }
    
    func testInsertedMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = try MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24).inserted(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["id"] as Int64, person.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
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

    func testSaveMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
            try person1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            var person2 = MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24)
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
    
    func testSavedMutablePersistableRecordPerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var person1 = try MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24).saved(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Arthur")
            
            let person2 = try MutablePersistableRecordPerson(id: nil, name: "Barbara", age: 24).saved(db)
            
            person1.name = "Craig"
            var savedPerson1 = try person1.saved(db)
            XCTAssertEqual(person1.id, savedPerson1.id)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["id"] as Int64, person1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
            
            try person1.delete(db)
            savedPerson1 = try person1.saved(db)
            XCTAssertEqual(person1.id, savedPerson1.id)
            
            rows = try Row.fetchAll(db, sql: "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["id"] as Int64, savedPerson1.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Craig")
            try XCTAssertEqual(rows[1]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[1]["name"] as String, "Barbara")
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
            try XCTAssertEqual(rows[0]["id"] as Int64, person2.id!)
            try XCTAssertEqual(rows[0]["name"] as String, "Barbara")
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
    
    func testMutablePersistableRecordPersonDatabaseDictionary() {
        let person = MutablePersistableRecordPerson(id: nil, name: "Arthur", age: 24)
        let dict = person.databaseDictionary
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
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }
    
    func testInsertedMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = try MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France").inserted(db)
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
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
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }

    func testSaveMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.save(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
            
            var country2 = MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            try country1.save(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
        }
    }
    
    func testSavedMutablePersistableRecordCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = try MutablePersistableRecordCountry(rowID: nil, isoCode: "FR", name: "France").saved(db)
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
            
            let country2 = try MutablePersistableRecordCountry(rowID: nil, isoCode: "US", name: "United States").saved(db)
            
            country1.name = "France Métropolitaine"
            var savedCountry1 = try country1.saved(db)
            XCTAssertEqual(country1.rowID, savedCountry1.rowID)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            try country1.delete(db)
            savedCountry1 = try country1.saved(db)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, savedCountry1.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
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
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
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
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
        }
    }

    func testUpdateMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
        }
    }

    func testSaveMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            var rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France")
            
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "France Métropolitaine")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "United States")
            
            _ = try country1.delete(db)
            try country1.save(db)
            
            XCTAssertEqual(insertCount, 2)
            XCTAssertEqual(updateCount, 3)
            XCTAssertEqual(saveCount, 3)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 0)
            
            rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
            try XCTAssertEqual(rows[1]["rowID"] as Int64, country1.rowID!)
            try XCTAssertEqual(rows[1]["name"] as String, "France Métropolitaine")
        }
    }

    func testDeleteMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            var country2 = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            let rows = try Row.fetchAll(db, sql: "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 1)
            try XCTAssertEqual(rows[0]["rowID"] as Int64, country2.rowID!)
            try XCTAssertEqual(rows[0]["name"] as String, "United States")
        }
    }

    func testExistsMutablePersistableRecordCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country = MutablePersistableRecordCustomizedCountry(
                rowID: nil,
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
            
            mutating func didInsert(with rowID: Int64, for column: String?) {
                id = rowID
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "records") { t in
                t.column("id", .integer).primaryKey()
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
                t.column("id", .integer).primaryKey()
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
    
    func testPersistenceErrorRecordNotFoundDescription() {
        do {
            let error = PersistenceError.recordNotFound(
                databaseTableName: "place",
                key: ["id": .null])
            XCTAssertEqual(
                error.description,
                "Key not found in table place: [id:NULL]")
        }
        do {
            let error = PersistenceError.recordNotFound(
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
