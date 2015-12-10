import XCTest
import GRDB

struct PersistablePersonThatIgnoresRowID : DatabasePersistable {
    var name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

struct PersistablePerson : DatabasePersistable {
    var id: Int64?
    var name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    mutating func didInsertWithRowID(rowID: Int64, forColumn name: String?) {
        self.id = rowID
    }
}

struct PersistableCountry : DatabasePersistable {
    var rowID: Int64?
    var isoCode: String
    var name: String
    
    init(isoCode: String, name: String) {
        self.rowID = nil
        self.isoCode = isoCode
        self.name = name
    }
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
    
    mutating func didInsertWithRowID(rowID: Int64, forColumn name: String?) {
        self.rowID = rowID
    }
}

class DatabasePersistableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name NOT NULL " +
                ")")
            try db.execute(
                "CREATE TABLE countries (" +
                    "isoCode TEXT NOT NULL PRIMARY KEY, " +
                    "name TEXT NOT NULL " +
                ")")
        }
        
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testInsertPersistablePersonThatIgnoresRowID() {
        assertNoError {
            try dbQueue.inDatabase { db in
                // TODO: avoid the `var` qualifier
                var person = PersistablePersonThatIgnoresRowID(name: "Arthur")
                try person.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testInsertPersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var person = PersistablePerson(id: nil, name: "Arthur")
                try person.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testUpdatePersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var person1 = PersistablePerson(id: nil, name: "Arthur")
                try person1.insert(db)
                var person2 = PersistablePerson(id: nil, name: "Barbara")
                try person2.insert(db)
                
                person1.name = "Craig"
                try person1.update(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
            }
        }
    }
    
    func testSavePersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var person1 = PersistablePerson(id: nil, name: "Arthur")
                try person1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                
                var person2 = PersistablePerson(id: nil, name: "Barbara")
                try person2.save(db)
                
                person1.name = "Craig"
                try person1.save(db)
                
                rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
            }
        }
    }
    
    func testDeletePersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var person1 = PersistablePerson(id: nil, name: "Arthur")
                try person1.insert(db)
                var person2 = PersistablePerson(id: nil, name: "Barbara")
                try person2.insert(db)
                
                person1.name = "Craig"
                try person1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Barbara")
            }
        }
    }
    
    func testExistsPersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var person = PersistablePerson(id: nil, name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.exists(db))
                
                person.name = "Craig"
                try person.delete(db)
                
                XCTAssertFalse(person.exists(db))
            }
        }
    }
    
    func testInsertPersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdatePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                var country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.update(db)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSavePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                var country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.save(db)
                
                country1.name = "France Métropolitaine"
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testDeletePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                var country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsPersistablecountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                XCTAssertTrue(country.exists(db))
                
                country.name = "France Métropolitaine"
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
            }
        }
    }
}
