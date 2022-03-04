import XCTest
import GRDB

private class Person : Record {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: Date!
    
    init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: Date? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    static func setup(inDatabase db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE persons (
                id INTEGER PRIMARY KEY,
                creationDate TEXT NOT NULL,
                name TEXT NOT NULL,
                age INT)
            """)
    }
    
    // Record
    
    override class var databaseTableName: String {
        "persons"
    }
    
    required init(row: Row) throws {
        id = try row["id"]
        age = try row["age"]
        name = try row["name"]
        creationDate = try row["creationDate"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["age"] = age
        container["creationDate"] = creationDate
    }
    
    override func insert(_ db: Database) throws {
        // This is implicitly tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = Date()
        }
        
        try super.insert(db)
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

private class IntegerPropertyOnRealAffinityColumn : Record {
    var value: Int?
    
    init(value: Int?) {
        self.value = value
        super.init()
    }
    
    // Record
    
    required init(row: Row) throws {
        value = try row["value"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["value"] = value
    }
}

private class PersonWithModifiedCaseColumns: Record {
    var id: Int64!
    var name: String!
    var age: Int?
    var creationDate: Date!
    
    init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: Date? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    // Record
    
    override class var databaseTableName: String {
        "persons"
    }
    
    required init(row: Row) throws {
        id = try row["ID"]
        age = try row["AGE"]
        name = try row["NAME"]
        creationDate = try row["CREATIONDATE"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["ID"] = id
        container["NAME"] = name
        container["AGE"] = age
        container["CREATIONDATE"] = creationDate
    }
    
    override func insert(_ db: Database) throws {
        // This is implicitly tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = Date()
        }
        
        try super.insert(db)
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        self.id = rowID
    }
}

class RecordEditedTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setup)
        try migrator.migrate(dbWriter)
    }
    
    func testRecordIsEditedAfterInit() {
        // Create a Record. No fetch has happen, so we don't know if it is
        // identical to its eventual row in the database. So it is edited.
        let person = Person(name: "Arthur", age: 41)
        XCTAssertTrue(person.hasDatabaseChanges)
    }
    
    func testRecordIsEditedAfterInitFromRow() throws {
        // Create a Record from a row. The row may not come from the database.
        // So it is edited.
        let row = Row(["name": "Arthur", "age": 41])
        let person = try Person(row: row)
        XCTAssertTrue(person.hasDatabaseChanges)
    }
    
    func testRecordIsNotEditedAfterFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container: An update statement, which only saves the
        // columns in persistence container would perform no change. So the
        // record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Arthur", age: 41).insert(db)
            let person = try Person.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertFalse(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
            let person = try PersonWithModifiedCaseColumns.fetchOne(db, sql: "SELECT * FROM persons")!
            XCTAssertFalse(person.hasDatabaseChanges)
        }
    }

    func testRecordIsNotEditedAfterFullFetchWithIntegerPropertyOnRealAffinityColumn() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (value REAL)")
            try db.execute(sql: "INSERT INTO t (value) VALUES (1)")
            let record = try IntegerPropertyOnRealAffinityColumn.fetchOne(db, sql: "SELECT * FROM t")!
            XCTAssertFalse(record.hasDatabaseChanges)
        }
    }

    func testRecordIsNotEditedAfterWiderThanFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container, plus extra ones: An update statement,
        // which only saves the columns in persistence container would
        // perform no change. So the record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Arthur", age: 41).insert(db)
            let person = try Person.fetchOne(db, sql: "SELECT *, 1 AS foo FROM persons")!
            XCTAssertFalse(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
            let person = try PersonWithModifiedCaseColumns.fetchOne(db, sql: "SELECT *, 1 AS foo FROM persons")!
            XCTAssertFalse(person.hasDatabaseChanges)
        }
    }

    func testRecordIsEditedAfterPartialFetch() throws {
        // Fetch a record from a row that does not contain all the columns in
        // persistence container: An update statement saves the columns in
        // persistence container, so it may perform unpredictable change.
        // So the record is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Arthur", age: 41).insert(db)
            let person = try Person.fetchOne(db, sql: "SELECT name FROM persons")!
            XCTAssertTrue(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
            let person = try PersonWithModifiedCaseColumns.fetchOne(db, sql: "SELECT name FROM persons")!
            XCTAssertTrue(person.hasDatabaseChanges)
        }
    }

    func testRecordIsNotEditedAfterInsert() throws {
        // After insertion, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
    }

    func testRecordIsEditedAfterValueChange() throws {
        // Any change in a value exposed in persistence container yields a
        // record that is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let person = Person(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
            do {
                let person = Person(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = nil               // non-nil vs. nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
            do {
                let person = Person(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.age == nil)
                person.age = 41                 // nil vs. non-nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
        }
        try dbQueue.inDatabase { db in
            do {
                let person = PersonWithModifiedCaseColumns(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = "Bobby"           // non-nil vs. non-nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
            do {
                let person = PersonWithModifiedCaseColumns(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = nil               // non-nil vs. nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
            do {
                let person = PersonWithModifiedCaseColumns(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.age == nil)
                person.age = 41                 // nil vs. non-nil
                XCTAssertTrue(person.hasDatabaseChanges)
            }
        }
    }

    func testRecordIsNotEditedAfterSameValueChange() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let person = Person(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = "Arthur"           // non-nil vs. non-nil
                XCTAssertFalse(person.hasDatabaseChanges)
            }
            do {
                let person = Person(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.age == nil)
                person.age = nil                 // nil vs. nil
                XCTAssertFalse(person.hasDatabaseChanges)
            }
        }
        try dbQueue.inDatabase { db in
            do {
                let person = PersonWithModifiedCaseColumns(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.name != nil)
                person.name = "Arthur"           // non-nil vs. non-nil
                XCTAssertFalse(person.hasDatabaseChanges)
            }
            do {
                let person = PersonWithModifiedCaseColumns(name: "Arthur")
                try person.insert(db)
                XCTAssertTrue(person.age == nil)
                person.age = nil                 // nil vs. nil
                XCTAssertFalse(person.hasDatabaseChanges)
            }
        }
    }

    func testRecordIsNotEditedAfterUpdate() throws {
        // After update, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            person.name = "Bobby"
            try person.update(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            person.name = "Bobby"
            try person.update(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
    }

    func testRecordIsNotEditedAfterSave() throws {
        // After save, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.save(db)
            XCTAssertFalse(person.hasDatabaseChanges)
            person.name = "Bobby"
            XCTAssertTrue(person.hasDatabaseChanges)
            try person.save(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.save(db)
            XCTAssertFalse(person.hasDatabaseChanges)
            person.name = "Bobby"
            XCTAssertTrue(person.hasDatabaseChanges)
            try person.save(db)
            XCTAssertFalse(person.hasDatabaseChanges)
        }
    }

    func testRecordIsEditedAfterPrimaryKeyChange() throws {
        // After reload, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            person.id = person.id + 1
            XCTAssertTrue(person.hasDatabaseChanges)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            person.id = person.id + 1
            XCTAssertTrue(person.hasDatabaseChanges)
        }
    }
    
    func testChangesAfterInit() {
        let person = Person(name: "Arthur", age: 41)
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "age":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterInitFromRow() throws {
        let person = try Person(row: Row(["name": "Arthur", "age": 41]))
        let changes = person.databaseChanges
        XCTAssertEqual(changes.count, 4)
        for (column, old) in changes {
            switch column {
            case "id":
                XCTAssertTrue(old == nil)
            case "name":
                XCTAssertTrue(old == nil)
            case "age":
                XCTAssertTrue(old == nil)
            case "creationDate":
                XCTAssertTrue(old == nil)
            default:
                XCTFail("Unexpected column: \(column)")
            }
        }
    }
    
    func testChangesAfterFullFetch() throws {
        // Fetch a record from a row that contains all the columns in
        // persistence container: An update statement, which only saves the
        // columns in persistence container would perform no change. So the
        // record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Arthur", age: 41).insert(db)
            do {
                let person = try Person.fetchOne(db, sql: "SELECT * FROM persons")!
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let persons = try Person.fetchAll(db, sql: "SELECT * FROM persons")
                let changes = persons[0].databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let persons = try Person.fetchCursor(db, sql: "SELECT * FROM persons")
                let changes = try persons.next()!.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
            do {
                let person = try Person.fetchOne(db, sql: "SELECT * FROM persons", adapter: SuffixRowAdapter(fromIndex: 0))!
                let changes = person.databaseChanges
                XCTAssertEqual(changes.count, 0)
            }
        }
        try dbQueue.inDatabase { db in
            try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
            let person = try PersonWithModifiedCaseColumns.fetchOne(db, sql: "SELECT * FROM persons")!
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 0)
        }
    }

    func testChangesAfterPartialFetch() throws {
        // Fetch a record from a row that does not contain all the columns in
        // persistence container: An update statement saves the columns in
        // persistence container, so it may perform unpredictable change.
        // So the record is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(name: "Arthur", age: 41).insert(db)
            let person = try Person.fetchOne(db, sql: "SELECT name FROM persons")!
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "id":
                    XCTAssertTrue(old == nil)
                case "age":
                    XCTAssertTrue(old == nil)
                case "creationDate":
                    XCTAssertTrue(old == nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
        try dbQueue.inDatabase { db in
            try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
            let person = try PersonWithModifiedCaseColumns.fetchOne(db, sql: "SELECT name FROM persons")!
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "ID":
                    XCTAssertTrue(old == nil)
                case "AGE":
                    XCTAssertTrue(old == nil)
                case "CREATIONDATE":
                    XCTAssertTrue(old == nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }

    func testChangesAfterInsert() throws {
        // After insertion, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 0)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 0)
        }
    }

    func testChangesAfterValueChange() throws {
        // Any change in a value exposed in persistence container yields a
        // record that is edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: nil)
            try person.insert(db)
            
            person.name = "Bobby"           // non-nil -> non-nil
            person.age = 41                 // nil -> non-nil
            person.creationDate = nil       // non-nil -> nil
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "name":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                case "age":
                    XCTAssertEqual(old, DatabaseValue.null)
                case "creationDate":
                    XCTAssertTrue(Date.fromDatabaseValue(old!) != nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: nil)
            try person.insert(db)
            
            person.name = "Bobby"           // non-nil -> non-nil
            person.age = 41                 // nil -> non-nil
            person.creationDate = nil       // non-nil -> nil
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 3)
            for (column, old) in changes {
                switch column {
                case "NAME":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                case "AGE":
                    XCTAssertEqual(old, DatabaseValue.null)
                case "CREATIONDATE":
                    XCTAssertTrue(Date.fromDatabaseValue(old!) != nil)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }

    func testChangesAfterUpdate() throws {
        // After update, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            person.name = "Bobby"
            try person.update(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            person.name = "Bobby"
            try person.update(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
        }
    }

    func testChangesAfterSave() throws {
        // After save, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.save(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
            
            person.name = "Bobby"
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "name":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
            try person.save(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.save(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
            
            person.name = "Bobby"
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "NAME":
                    XCTAssertEqual(old, "Arthur".databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
            try person.save(db)
            XCTAssertEqual(person.databaseChanges.count, 0)
        }
    }

    func testChangesAfterPrimaryKeyChange() throws {
        // After reload, a record is not edited.
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            try person.insert(db)
            person.id = person.id + 1
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "id":
                    XCTAssertEqual(old, (person.id - 1).databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
        try dbQueue.inDatabase { db in
            let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
            try person.insert(db)
            person.id = person.id + 1
            let changes = person.databaseChanges
            XCTAssertEqual(changes.count, 1)
            for (column, old) in changes {
                switch column {
                case "ID":
                    XCTAssertEqual(old, (person.id - 1).databaseValue)
                default:
                    XCTFail("Unexpected column: \(column)")
                }
            }
        }
    }
    
    func testUpdateChanges() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let person = Person(name: "Arthur", age: 41)
            
            do {
                XCTAssertTrue(person.hasDatabaseChanges)
                try person.updateChanges(db)
                XCTFail("Expected PersistenceError")
            } catch is PersistenceError { }
            
            try person.insert(db)

            // Nothing to update
            let initialChangesCount = db.totalChangesCount
            XCTAssertFalse(person.hasDatabaseChanges)
            try XCTAssertFalse(person.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount)
            
            // Nothing to update
            person.age = 41
            XCTAssertFalse(person.hasDatabaseChanges)
            try XCTAssertFalse(person.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount)
            
            // Update single column
            person.age = 42
            XCTAssertEqual(Set(person.databaseChanges.keys), ["age"])
            try XCTAssertTrue(person.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount + 1)
            XCTAssertEqual(lastSQLQuery, "UPDATE \"persons\" SET \"age\"=42 WHERE \"id\"=1")
            
            // Update two columns
            person.name = "Barbara"
            person.age = 43
            XCTAssertEqual(Set(person.databaseChanges.keys), ["age", "name"])
            try XCTAssertTrue(person.updateChanges(db))
            XCTAssertEqual(db.totalChangesCount, initialChangesCount + 2)
            let fetchedPerson = try Person.fetchOne(db, key: person.id)
            XCTAssertEqual(fetchedPerson?.name, person.name)
            XCTAssertEqual(fetchedPerson?.age, person.age)
        }
    }
}
