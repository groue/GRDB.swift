import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

private struct MutablePersistablePerson : MutablePersistable {
    var id: Int64?
    var name: String?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name]
    }
    
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

private struct MutablePersistableCountry : MutablePersistable {
    var rowID: Int64?
    var isoCode: String
    var name: String
    
    static func databaseTableName() -> String {
        return "countries"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["isoCode": isoCode, "name": name]
    }
    
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.rowID = rowID
    }
}

private struct MutablePersistableCustomizedCountry : MutablePersistable {
    var rowID: Int64?
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
    
    mutating func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.rowID = rowID
    }
    
    mutating func insert(db: DatabaseWriter) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(db: DatabaseWriter) throws {
        willUpdate()
        try performUpdate(db)
    }
    
    mutating func save(db: Database) throws {
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

class DatabasePoolMutablePersistableTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
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
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - MutablePersistablePerson
    
    func testInsertMutablePersistablePerson() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var person = MutablePersistablePerson(id: nil, name: "Arthur")
            try person.insert(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
        }
    }
    
    func testUpdateMutablePersistablePerson() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var person1 = MutablePersistablePerson(id: nil, name: "Arthur")
            try person1.insert(dbPool)
            var person2 = MutablePersistablePerson(id: nil, name: "Barbara")
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
    
    func testDeleteMutablePersistablePerson() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var person1 = MutablePersistablePerson(id: nil, name: "Arthur")
            try person1.insert(dbPool)
            var person2 = MutablePersistablePerson(id: nil, name: "Barbara")
            try person2.insert(dbPool)
            
            try person1.delete(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT * FROM persons ORDER BY id")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "id") as Int64, person2.id!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "Barbara")
        }
    }
    
    func testExistsMutablePersistablePerson() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var person = MutablePersistablePerson(id: nil, name: "Arthur")
            try person.insert(dbPool)
            XCTAssertTrue(person.exists(dbPool))
            
            try person.delete(dbPool)
            
            XCTAssertFalse(person.exists(dbPool))
        }
    }
    
    
    // MARK: - MutablePersistableCountry
    
    func testInsertMutablePersistableCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var country = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
            try country.insert(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }
    
    func testUpdateMutablePersistableCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var country1 = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.insert(dbPool)
            var country2 = MutablePersistableCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.insert(dbPool)
            
            country1.name = "France Métropolitaine"
            try country1.update(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }
    
    func testDeleteMutablePersistableCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var country1 = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
            try country1.insert(dbPool)
            var country2 = MutablePersistableCountry(rowID: nil, isoCode: "US", name: "United States")
            try country2.insert(dbPool)
            
            try country1.delete(dbPool)
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }
    
    func testExistsMutablePersistableCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var country = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
            try country.insert(dbPool)
            XCTAssertTrue(country.exists(dbPool))
            
            try country.delete(dbPool)
            
            XCTAssertFalse(country.exists(dbPool))
        }
    }
    
    
    // MARK: - MutablePersistableCustomizedCountry
    
    func testInsertMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country = MutablePersistableCustomizedCountry(
                rowID: nil,
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
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "France")
        }
    }
    
    func testUpdateMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = MutablePersistableCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(dbPool)
            var country2 = MutablePersistableCustomizedCountry(
                rowID: nil,
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
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
            XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
            XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
        }
    }
    
    func testDeleteMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country1 = MutablePersistableCustomizedCountry(
                rowID: nil,
                isoCode: "FR",
                name: "France",
                willInsert: { insertCount += 1 },
                willUpdate: { updateCount += 1 },
                willSave: { saveCount += 1 },
                willDelete: { deleteCount += 1 },
                willExists: { existsCount += 1 })
            try country1.insert(dbPool)
            var country2 = MutablePersistableCustomizedCountry(
                rowID: nil,
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
            
            let rows = Row.fetchAll(dbPool, "SELECT rowID, * FROM countries ORDER BY rowID")
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
            XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
        }
    }
    
    func testExistsMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbPool = try makeDatabasePool()
            
            var insertCount: Int = 0
            var updateCount: Int = 0
            var saveCount: Int = 0
            var deleteCount: Int = 0
            var existsCount: Int = 0
            var country = MutablePersistableCustomizedCountry(
                rowID: nil,
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
