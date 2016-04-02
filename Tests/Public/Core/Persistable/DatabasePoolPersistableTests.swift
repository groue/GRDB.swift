import XCTest
import GRDB

private struct PersistablePerson : Persistable {
    var name: String?
    var age: Int?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "age": age]
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
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "age": age]
    }
    
    func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

private struct PersistableCountry : Persistable {
    var isoCode: String
    var name: String
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
}

private struct PersistableCustomizedCountry : Persistable {
    var isoCode: String
    var name: String
    let willInsert: Void -> Void
    let willUpdate: Void -> Void
    let willSave: Void -> Void
    let willDelete: Void -> Void
    let willExists: Void -> Void
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
    
    func insert(db: DatabaseWriter) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(db: DatabaseWriter) throws {
        willUpdate()
        try performUpdate(db)
    }
    
    func save(db: Database) throws {
        willSave()
        try performSave(db)
    }
    
    func delete(db: DatabaseWriter) throws {
        willDelete()
        try performDelete(db)
    }
    
    func exists(db: DatabaseReader) -> Bool {
        willExists()
        return performExists(db)
    }
}

class DatabasePoolPersistableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
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
        }
        
        assertNoError {
            try migrator.migrate(dbPool)
        }
    }
    
    
    // MARK: - PersistablePerson
    
    func testInsertPersistablePerson() {
        assertNoError {
            let person = PersistablePerson(name: "Arthur", age: 42)
            try person.insert(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }
    
    
    // MARK: - PersistablePersonClass
    
    func testInsertPersistablePersonClass() {
        assertNoError {
            let person = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }
    
    func testUpdatePersistablePersonClass() {
        assertNoError {
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(dbPool)
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 39)
            try person2.insert(dbPool)
            
            person1.name = "Craig"
            try person1.update(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
            XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
        }
    }
    
    func testDeletePersistablePersonClass() {
        assertNoError {
            let person1 = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person1.insert(dbPool)
            let person2 = PersistablePersonClass(id: nil, name: "Barbara", age: 39)
            try person2.insert(dbPool)
            
            try person1.delete(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Barbara")
        }
    }
    
    func testExistsPersistablePersonClass() {
        assertNoError {
            let person = PersistablePersonClass(id: nil, name: "Arthur", age: 42)
            try person.insert(dbPool)
            XCTAssertTrue(person.exists(dbPool))
            
            try person.delete(dbPool)
            
            XCTAssertFalse(person.exists(dbPool))
        }
    }
    
    
    // MARK: - PersistableCountry
    
    func testInsertPersistableCountry() {
        assertNoError {
            let country = PersistableCountry(isoCode: "FR", name: "France")
            try country.insert(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }
    
    func testUpdatePersistableCountry() {
        assertNoError {
            var country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.insert(dbPool)
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.insert(dbPool)
            
            country1.name = "France Métropolitaine"
            try country1.update(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }
    
    func testDeletePersistableCountry() {
        assertNoError {
            let country1 = PersistableCountry(isoCode: "FR", name: "France")
            try country1.insert(dbPool)
            let country2 = PersistableCountry(isoCode: "US", name: "United States")
            try country2.insert(dbPool)
            
            try country1.delete(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }
    
    func testExistsPersistableCountry() {
        assertNoError {
            let country = PersistableCountry(isoCode: "FR", name: "France")
            try country.insert(dbPool)
            XCTAssertTrue(country.exists(dbPool))
            
            try country.delete(dbPool)
            
            XCTAssertFalse(country.exists(dbPool))
        }
    }
    
    
    // MARK: - PersistableCustomizedCountry
    
    func testInsertPersistableCustomizedCountry() {
        assertNoError {
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
            try country.insert(dbPool)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }
    
    func testUpdatePersistableCustomizedCountry() {
        assertNoError {
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
            try country1.insert(dbPool)
            let country2 = PersistableCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.insert(dbPool)
            
            country1.name = "France Métropolitaine"
            try country1.update(dbPool)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 1)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 0)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }
    
    func testDeletePersistableCustomizedCountry() {
        assertNoError {
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
            try country1.insert(dbPool)
            let country2 = PersistableCustomizedCountry(
                isoCode: "US",
                name: "United States",
                willInsert: { },
                willUpdate: { },
                willSave: { },
                willDelete: { },
                willExists: { })
            try country2.insert(dbPool)
            
            try country1.delete(dbPool)
            
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 0)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM countries ORDER BY isoCode")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }
    
    func testExistsPersistableCustomizedCountry() {
        assertNoError {
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
            try country.insert(dbPool)
            
            XCTAssertTrue(country.exists(dbPool))
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 0)
            XCTAssertEqual(existsCount, 1)
            
            try country.delete(dbPool)
            
            XCTAssertFalse(country.exists(dbPool))
            XCTAssertEqual(insertCount, 1)
            XCTAssertEqual(updateCount, 0)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(deleteCount, 1)
            XCTAssertEqual(existsCount, 2)
        }
    }
}
