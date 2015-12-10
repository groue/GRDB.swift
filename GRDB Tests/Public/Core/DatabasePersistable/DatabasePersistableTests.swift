import XCTest
import GRDB

struct PersistablePerson : DatabasePersistable {
    var name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

struct PersistableCountry : DatabasePersistable {
    var isoCode: String
    var name: String
    
    init(isoCode: String, name: String) {
        self.isoCode = isoCode
        self.name = name
    }
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
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
    
    func testInsertPersistablePerson() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let person = PersistablePerson(name: "Arthur")
                try person.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testInsertPersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdatePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.update(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSavePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.save(db)
                
                country1.name = "France Métropolitaine"
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "FR")
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testDeletePersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country1 = PersistableCountry(isoCode: "FR", name: "France")
                try country1.insert(db)
                let country2 = PersistableCountry(isoCode: "US", name: "United States")
                try country2.insert(db)
                
                try country1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM countries ORDER BY isoCode")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "isoCode") as String, "US")
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsPersistableCountry() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let country = PersistableCountry(isoCode: "FR", name: "France")
                try country.insert(db)
                XCTAssertTrue(country.exists(db))
                
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
            }
        }
    }
}
