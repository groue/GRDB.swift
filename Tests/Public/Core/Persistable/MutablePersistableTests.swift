import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct MutablePersistablePerson : MutablePersistable {
    var id: Int64?
    var name: String?
    var age: Int?
    
    static func databaseTableName() -> String {
        return "persons"
    }
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["iD": id, "NAme": name, "aGe": age] // various cases
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
    
    mutating func insert(db: Database) throws {
        willInsert()
        try performInsert(db)
    }
    
    func update(db: Database, columns: Set<String>) throws {
        willUpdate()
        try performUpdate(db, columns: columns)
    }
    
    mutating func save(db: Database) throws {
        willSave()
        try performSave(db)
    }
    
    func delete(db: Database) throws -> Bool {
        willDelete()
        return try performDelete(db)
    }
    
    func exists(db: Database) -> Bool {
        willExists()
        return performExists(db)
    }
}

class MutablePersistableTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("setUp") { db in
            try db.execute(
                "CREATE TABLE persons (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name NOT NULL, " +
                    "age INTEGER" +
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
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
            }
        }
    }
    
    func testUpdateMutablePersistablePerson() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person1 = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person1.insert(db)
                var person2 = MutablePersistablePerson(id: nil, name: "Barbara", age: 24)
                try person2.insert(db)
                
                person1.name = "Craig"
                try person1.update(db)
                XCTAssertTrue([
                    "UPDATE \"persons\" SET \"age\"=24, \"name\"='Craig' WHERE \"id\"=1",
                    "UPDATE \"persons\" SET \"name\"='Craig', \"age\"=24 WHERE \"id\"=1"
                    ].contains(self.lastSQLQuery))
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
            }
        }
    }
    
    func testPartialUpdateMutablePersistablePerson() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person1 = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person1.insert(db)
                var person2 = MutablePersistablePerson(id: nil, name: "Barbara", age: 36)
                try person2.insert(db)
                
                do {
                    person1.name = "Craig"
                    try person1.update(db, columns: [String]())
                    XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"id\"=1 WHERE \"id\"=1")
                    
                    let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
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
                    try person1.update(db, columns: [SQLColumn("name")])
                    XCTAssertEqual(self.lastSQLQuery, "UPDATE \"persons\" SET \"name\"='Craig' WHERE \"id\"=1")
                    
                    let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
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
                    
                    let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
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
    }
    
    func testSaveMutablePersistablePerson() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person1 = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT * FROM persons")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Arthur")
                
                var person2 = MutablePersistablePerson(id: nil, name: "Barbara", age: 24)
                try person2.save(db)
                
                person1.name = "Craig"
                try person1.save(db)
                
                rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person1.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Craig")
                XCTAssertEqual(rows[1].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "Barbara")
                
                try person1.delete(db)
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
    
    func testDeleteMutablePersistablePerson() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person1 = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person1.insert(db)
                var person2 = MutablePersistablePerson(id: nil, name: "Barbara", age: 24)
                try person2.insert(db)
                
                // TODO: test delete return value
                try person1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT * FROM persons ORDER BY id")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "id") as Int64, person2.id!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "Barbara")
            }
        }
    }
    
    func testExistsMutablePersistablePerson() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var person = MutablePersistablePerson(id: nil, name: "Arthur", age: 24)
                try person.insert(db)
                XCTAssertTrue(person.exists(db))
                
                try person.delete(db)
                
                XCTAssertFalse(person.exists(db))
            }
        }
    }
    
    
    // MARK: - MutablePersistableCountry
    
    func testInsertMutablePersistableCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var country = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
                try country.insert(db)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdateMutablePersistableCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var country1 = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
                try country1.insert(db)
                var country2 = MutablePersistableCountry(rowID: nil, isoCode: "US", name: "United States")
                try country2.insert(db)
                
                country1.name = "France Métropolitaine"
                try country1.update(db)
                XCTAssertEqual(self.lastSQLQuery, "UPDATE \"countries\" SET \"name\"='France Métropolitaine' WHERE \"isoCode\"='FR'")
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSaveMutablePersistableCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var country1 = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
                try country1.save(db)
                
                var rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                var country2 = MutablePersistableCountry(rowID: nil, isoCode: "US", name: "United States")
                try country2.save(db)
                
                country1.name = "France Métropolitaine"
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
                
                try country1.delete(db)
                try country1.save(db)
                
                rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "France Métropolitaine")
            }
        }
    }
    
    func testDeleteMutablePersistableCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var country1 = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
                try country1.insert(db)
                var country2 = MutablePersistableCountry(rowID: nil, isoCode: "US", name: "United States")
                try country2.insert(db)
                
                // TODO: test delete return value
                try country1.delete(db)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsMutablePersistableCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var country = MutablePersistableCountry(rowID: nil, isoCode: "FR", name: "France")
                try country.insert(db)
                XCTAssertTrue(country.exists(db))
                
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
            }
        }
    }
    
    
    // MARK: - MutablePersistableCustomizedCountry
    
    func testInsertMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
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
                try country.insert(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
            }
        }
    }
    
    func testUpdateMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
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
                try country1.insert(db)
                var country2 = MutablePersistableCustomizedCountry(
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
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testSaveMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
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
                try country1.save(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 1)
                XCTAssertEqual(saveCount, 1)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 0)
                
                var rows = Row.fetchAll(db, "SELECT rowID, * FROM countries")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France")
                
                var country2 = MutablePersistableCustomizedCountry(
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
                
                rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "France Métropolitaine")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "United States")
                
                try country1.delete(db)
                try country1.save(db)
                
                XCTAssertEqual(insertCount, 2)
                XCTAssertEqual(updateCount, 3)
                XCTAssertEqual(saveCount, 3)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 0)
                
                rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 2)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
                XCTAssertEqual(rows[1].value(named: "rowID") as Int64, country1.rowID!)
                XCTAssertEqual(rows[1].value(named: "name") as String, "France Métropolitaine")
            }
        }
    }
    
    func testDeleteMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
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
                try country1.insert(db)
                var country2 = MutablePersistableCustomizedCountry(
                    rowID: nil,
                    isoCode: "US",
                    name: "United States",
                    willInsert: { },
                    willUpdate: { },
                    willSave: { },
                    willDelete: { },
                    willExists: { })
                try country2.insert(db)
                
                // TODO: test delete return value
                try country1.delete(db)
                
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 0)
                
                let rows = Row.fetchAll(db, "SELECT rowID, * FROM countries ORDER BY rowID")
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0].value(named: "rowID") as Int64, country2.rowID!)
                XCTAssertEqual(rows[0].value(named: "name") as String, "United States")
            }
        }
    }
    
    func testExistsMutablePersistableCustomizedCountry() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
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
                try country.insert(db)
                
                XCTAssertTrue(country.exists(db))
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 0)
                XCTAssertEqual(existsCount, 1)
                
                try country.delete(db)
                
                XCTAssertFalse(country.exists(db))
                XCTAssertEqual(insertCount, 1)
                XCTAssertEqual(updateCount, 0)
                XCTAssertEqual(saveCount, 0)
                XCTAssertEqual(deleteCount, 1)
                XCTAssertEqual(existsCount, 2)
            }
        }
    }
}
