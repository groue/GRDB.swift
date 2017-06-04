import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct PersistablePerson : Persistable {
    var name: String?
    var age: Int?
    
    static let databaseTableName = "persons"
    
    func encode(to container: inout PersistenceContainer) {
        container["name"] = name
        container["age"] = age
    }
}

private class PersistablePersonClass : Persistable {
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

private struct PersistableCountry : Persistable {
    var isoCode: String
    var name: String
    
    static let databaseTableName = "countries"
    
    func encode(to container: inout PersistenceContainer) {
        container["isoCode"] = isoCode
        container["name"] = name
    }
}

private struct PersistableCustomizedCountry : Persistable {
    var isoCode: String
    var name: String
    let willInsert: (Void) -> Void
    let willUpdate: (Void) -> Void
    let willSave: (Void) -> Void
    let willDelete: (Void) -> Void
    let willExists: (Void) -> Void
    
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

private struct Citizenship : Persistable {
    let personID: Int64
    let countryIsoCode: String
    
    static let databaseTableName = "citizenships"
    
    func encode(to container: inout PersistenceContainer) {
        container["countryIsoCode"] = countryIsoCode
        container["personID"] = personID
    }
}

class PersistableTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT NOT NULL, " +
                    "age INT NOT NULL " +
                ")")
            try db.execute(
                "CREATE TABLE countries (" +
                    "isoCode TEXT NOT NULL PRIMARY KEY, " +
                    "name TEXT NOT NULL " +
                ")")
            try db.execute(
                "CREATE TABLE citizenships (" +
                    "countryIsoCode TEXT NOT NULL REFERENCES countries(isoCode), " +
                    "personID INTEGER NOT NULL REFERENCES persons(id)" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - PersistablePerson
    
    func testInsertPersistablePerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistablePerson(name: "Arthur", age: 42)
            try person.insert(db)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }

    func testSavePersistablePerson() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistablePerson(name: "Arthur", age: 42)
            try person.save(db)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }


    // MARK: - PersistablePersonClass
    
    func testInsertPersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(db)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }

    func testUpdatePersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(db)
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 39)
            try person2.insert(db)
            
            person1.name = "Craig"
            try person1.update(db)
            XCTAssertTrue([
                "UPDATE \"persons\" SET \"age\"=42, \"name\"='Craig' WHERE \"id\"=1",
                "UPDATE \"persons\" SET \"name\"='Craig', \"age\"=42 WHERE \"id\"=1"
                ].contains(self.lastSQLQuery))
            
            let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
            XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
        }
    }

    func testPartialUpdatePersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 24)
            try person1.insert(db)
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 36)
            try person2.insert(db)
            
            do {
                person1.name = "Craig"
                try person1.update(db, columns: [String]())
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"id\"=1 WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 24)
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 36)
            }
            
            do {
                person1.name = "Craig"
                person1.age = 25
                try person1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"name\"='Craig' WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 24)
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 36)
            }
            
            do {
                person1.name = "David"
                try person1.update(db, columns: ["AgE"])    // case insensitivity
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"AgE\"=25 WHERE \"id\"=1")
                
                let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[0].value(named: "age") as Int, 25)
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                XCTAssertEqual(rows[1].value(named: "age") as Int, 36)
            }
        }
    }

    func testSavePersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person1.save(db)
            
            var rows = try Row.fetchAll(db, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 39)
            try person2.save(db)
            
            person1.name = "Craig"
            try person1.save(db)
            
            rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
            XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
            
            try person1.delete(db)
            try person1.save(db)
            
            rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
            XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
        }
    }

    func testDeletePersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(db)
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 39)
            try person2.insert(db)
            
            var deleted = try person1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try person1.delete(db)
            XCTAssertFalse(deleted)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Barbara")
        }
    }

    func testExistsPersistablePersonClass() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(db)
            XCTAssertTrue(try person.exists(db))
            
            try person.delete(db)
            XCTAssertFalse(try person.exists(db))
        }
    }


    // MARK: - PersistableCountry
    
    func testInsertPersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableCountry(isoCode: "FR", name: "France")
            try country.insert(db)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }

    func testUpdatePersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            country1.name = "France Métropolitaine"
            try country1.update(db)
            XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }

    func testPartialUpdatePersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            do {
                country1.name = "France Métropolitaine"
                try country1.update(db, columns: [String]())
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"isoCode\"='FR' WHERE \"isoCode\"='FR'")
                
                let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
            
            do {
                country1.name = "France Métropolitaine"
                try country1.update(db, columns: [Column("name")])
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
                
                let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }

    func testSavePersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.save(db)
            
            var rows = try Row.fetchAll(db, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.save(db)
            
            country1.name = "France Métropolitaine"
            try country1.save(db)
            
            rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            
            try country1.delete(db)
            try country1.save(db)
            
            rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }

    func testDeletePersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.insert(db)
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.insert(db)
            
            var deleted = try country1.delete(db)
            XCTAssertTrue(deleted)
            deleted = try country1.delete(db)
            XCTAssertFalse(deleted)
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }

    func testExistsPersistableCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let country = PersistableCountry(isoCode: "FR", name: "France")
            try country.insert(db)
            XCTAssertTrue(try country.exists(db))
            
            try country.delete(db)
            XCTAssertFalse(try country.exists(db))
        }
    }


    // MARK: - PersistableCustomizedCountry
    
    func testInsertPersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country = PersistableCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }

    func testUpdatePersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }

    func testPartialUpdatePersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }

    func testSavePersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = PersistableCustomizedCountry(
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
            
            var rows = try Row.fetchAll(db, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            
            let country2 = PersistableCustomizedCountry(
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
            
            rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            
            _ = try country1.delete(db)
            try country1.save(db)
            
            XCTAssertEqual(insertCount, 2)
            XCTAssertEqual(updateCount, 3)
            XCTAssertEqual(saveCount, 3)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 0)
            
            rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }

    func testDeletePersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country1 = PersistableCustomizedCountry(
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(db)
            let country2 = PersistableCustomizedCountry(
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
            
            let rows = try Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }

    func testExistsPersistableCustomizedCountry() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            let country = PersistableCustomizedCountry(
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
            let person = PersistablePersonClass(id: nil, name: "Arthur", age: 12)
            try person.insert(db)
            try PersistableCountry(isoCode: "FR", name: "France").insert(db)
            do {
                try Citizenship(personID: person.id!, countryIsoCode: "US").insert(db)
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_CONSTRAINT)
            }
            try Citizenship(personID: person.id!, countryIsoCode: "FR").insert(db)
        }
    }
}
