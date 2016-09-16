import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT NOT NULL, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
    
    // Record
    
    override class var databaseTableName: String {
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "id")
        age = row.value(named: "age")
        name = row.value(named: "name")
        creationDate = row.value(named: "creationDate")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationDate": creationDate,
        ]
    }
    
    override func insert(_ db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
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
    var value: Int!
    
    init(value: Int?) {
        self.value = value
        super.init()
    }
    
    // Record
    
    required init(row: Row) {
        value = row.value(named: "value")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["value": value]
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
        return "persons"
    }
    
    required init(row: Row) {
        id = row.value(named: "ID")
        age = row.value(named: "AGE")
        name = row.value(named: "NAME")
        creationDate = row.value(named: "CREATIONDATE")
        super.init(row: row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "ID": id,
            "NAME": name,
            "AGE": age,
            "CREATIONDATE": creationDate,
        ]
    }
    
    override func insert(_ db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
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
        XCTAssertTrue(person.hasPersistentChangedValues)
    }
    
    func testRecordIsEditedAfterInitFromRow() {
        // Create a Record from a row. The row may not come from the database.
        // So it is edited.
        let row = Row(["name": "Arthur", "age": 41])
        let person = Person(row: row)
        XCTAssertTrue(person.hasPersistentChangedValues)
    }
    
    func testRecordIsNotEditedAfterFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // persistentDictionary: An update statement, which only saves the
        // columns in persistentDictionary would perform no change. So the
        // record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
                let person = PersonWithModifiedCaseColumns.fetchOne(db, "SELECT * FROM persons")!
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsNotEditedAfterFullFetchWithIntegerPropertyOnRealAffinityColumn() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE t (value REAL)")
                try db.execute("INSERT INTO t (value) VALUES (1)")
                
                // Load a double...
                let row1 = Row.fetchOne(db, "SELECT * FROM t")!
                switch (row1.value(named: "value") as DatabaseValue).storage {
                case .double(let double):
                    XCTAssertEqual(double, 1.0)
                default:
                    XCTFail("Unexpected DatabaseValue")
                }
                
                // Compare to an Int
                let record = IntegerPropertyOnRealAffinityColumn.fetchOne(db, "SELECT * FROM t")!
                let row2 = Row(record.persistentDictionary)
                switch (row2.value(named: "value") as DatabaseValue).storage {
                case .int64(let int64):
                    XCTAssertEqual(int64, 1)
                default:
                    XCTFail("Unexpected DatabaseValue")
                }
                
                XCTAssertFalse(record.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsNotEditedAfterWiderThanFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // persistentDictionary, plus extra ones: An update statement,
        // which only saves the columns in persistentDictionary would
        // perform no change. So the record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT *, 1 AS foo FROM persons")!
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
                let person = PersonWithModifiedCaseColumns.fetchOne(db, "SELECT *, 1 AS foo FROM persons")!
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsEditedAfterPartialFetch() {
        // Fetch a record from a row that does not contain all the columns in
        // persistentDictionary: An update statement saves the columns in
        // persistentDictionary, so it may perform unpredictable change.
        // So the record is edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  Person.fetchOne(db, "SELECT name FROM persons")!
                XCTAssertTrue(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
                let person =  PersonWithModifiedCaseColumns.fetchOne(db, "SELECT name FROM persons")!
                XCTAssertTrue(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsNotEditedAfterInsert() {
        // After insertion, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.insert(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsEditedAfterValueChange() {
        // Any change in a value exposed in persistentDictionary yields a
        // record that is edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Bobby"           // non-nil vs. non-nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = nil               // non-nil vs. nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = 41                 // nil vs. non-nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
            }
            try dbQueue.inDatabase { db in
                do {
                    let person = PersonWithModifiedCaseColumns(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Bobby"           // non-nil vs. non-nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
                do {
                    let person = PersonWithModifiedCaseColumns(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = nil               // non-nil vs. nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
                do {
                    let person = PersonWithModifiedCaseColumns(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = 41                 // nil vs. non-nil
                    XCTAssertTrue(person.hasPersistentChangedValues)
                }
            }
        }
    }
    
    func testRecordIsNotEditedAfterSameValueChange() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Arthur"           // non-nil vs. non-nil
                    XCTAssertFalse(person.hasPersistentChangedValues)
                }
                do {
                    let person = Person(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = nil                 // nil vs. nil
                    XCTAssertFalse(person.hasPersistentChangedValues)
                }
            }
            try dbQueue.inDatabase { db in
                do {
                    let person = PersonWithModifiedCaseColumns(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.name != nil)
                    person.name = "Arthur"           // non-nil vs. non-nil
                    XCTAssertFalse(person.hasPersistentChangedValues)
                }
                do {
                    let person = PersonWithModifiedCaseColumns(name: "Arthur")
                    try person.insert(db)
                    XCTAssertTrue(person.age == nil)
                    person.age = nil                 // nil vs. nil
                    XCTAssertFalse(person.hasPersistentChangedValues)
                }
            }
        }
    }
    
    func testRecordIsNotEditedAfterUpdate() {
        // After update, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsNotEditedAfterSave() {
        // After save, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
                person.name = "Bobby"
                XCTAssertTrue(person.hasPersistentChangedValues)
                try person.save(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
                person.name = "Bobby"
                XCTAssertTrue(person.hasPersistentChangedValues)
                try person.save(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testRecordIsEditedAfterPrimaryKeyChange() {
        // After reload, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.id = person.id + 1
                XCTAssertTrue(person.hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.insert(db)
                person.id = person.id + 1
                XCTAssertTrue(person.hasPersistentChangedValues)
            }
        }
    }
    
    func testCopyTransfersEditedFlag() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
                XCTAssertFalse(person.copy().hasPersistentChangedValues)
                
                person.name = "Barbara"
                XCTAssertTrue(person.hasPersistentChangedValues)
                XCTAssertTrue(person.copy().hasPersistentChangedValues)
                
                person.hasPersistentChangedValues = false
                XCTAssertFalse(person.hasPersistentChangedValues)
                XCTAssertFalse(person.copy().hasPersistentChangedValues)
                
                person.hasPersistentChangedValues = true
                XCTAssertTrue(person.hasPersistentChangedValues)
                XCTAssertTrue(person.copy().hasPersistentChangedValues)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertFalse(person.hasPersistentChangedValues)
                XCTAssertFalse(person.copy().hasPersistentChangedValues)
                
                person.name = "Barbara"
                XCTAssertTrue(person.hasPersistentChangedValues)
                XCTAssertTrue(person.copy().hasPersistentChangedValues)
                
                person.hasPersistentChangedValues = false
                XCTAssertFalse(person.hasPersistentChangedValues)
                XCTAssertFalse(person.copy().hasPersistentChangedValues)
                
                person.hasPersistentChangedValues = true
                XCTAssertTrue(person.hasPersistentChangedValues)
                XCTAssertTrue(person.copy().hasPersistentChangedValues)
            }
        }
    }

    func testChangesAfterInit() {
        let person = Person(name: "Arthur", age: 41)
        let changes = person.persistentChangedValues
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
    
    func testChangesAfterInitFromRow() {
        let person = Person(row: Row(["name": "Arthur", "age": 41]))
        let changes = person.persistentChangedValues
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
    
    func testChangesAfterFullFetch() {
        // Fetch a record from a row that contains all the columns in
        // persistentDictionary: An update statement, which only saves the
        // columns in persistentDictionary would perform no change. So the
        // record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person = Person.fetchOne(db, "SELECT * FROM persons")!
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 0)
            }
            try dbQueue.inDatabase { db in
                try PersonWithModifiedCaseColumns(name: "Arthur", age: 41).insert(db)
                let person = PersonWithModifiedCaseColumns.fetchOne(db, "SELECT * FROM persons")!
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 0)
            }
        }
    }

    func testChangesAfterPartialFetch() {
        // Fetch a record from a row that does not contain all the columns in
        // persistentDictionary: An update statement saves the columns in
        // persistentDictionary, so it may perform unpredictable change.
        // So the record is edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try Person(name: "Arthur", age: 41).insert(db)
                let person =  Person.fetchOne(db, "SELECT name FROM persons")!
                let changes = person.persistentChangedValues
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
                let person =  PersonWithModifiedCaseColumns.fetchOne(db, "SELECT name FROM persons")!
                let changes = person.persistentChangedValues
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
    }
    
    func testChangesAfterInsert() {
        // After insertion, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 0)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.insert(db)
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 0)
            }
        }
    }
    
    func testChangesAfterValueChange() {
        // Any change in a value exposed in persistentDictionary yields a
        // record that is edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: nil)
                try person.insert(db)
                
                person.name = "Bobby"           // non-nil -> non-nil
                person.age = 41                 // nil -> non-nil
                person.creationDate = nil       // non-nil -> nil
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 3)
                for (column, old) in changes {
                    switch column {
                    case "name":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                    case "age":
                        XCTAssertEqual(old, DatabaseValue.null)
                    case "creationDate":
                        XCTAssertTrue((old?.value() as Date?) != nil)
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
                let changes = person.persistentChangedValues
                XCTAssertEqual(changes.count, 3)
                for (column, old) in changes {
                    switch column {
                    case "NAME":
                        XCTAssertEqual(old, "Arthur".databaseValue)
                    case "AGE":
                        XCTAssertEqual(old, DatabaseValue.null)
                    case "CREATIONDATE":
                        XCTAssertTrue((old?.value() as Date?) != nil)
                    default:
                        XCTFail("Unexpected column: \(column)")
                    }
                }
            }
        }
    }
    
    func testChangesAfterUpdate() {
        // After update, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.insert(db)
                person.name = "Bobby"
                try person.update(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
            }
        }
    }
    
    func testChangesAfterSave() {
        // After save, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                
                person.name = "Bobby"
                let changes = person.persistentChangedValues
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
                XCTAssertEqual(person.persistentChangedValues.count, 0)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                try person.save(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                
                person.name = "Bobby"
                let changes = person.persistentChangedValues
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
                XCTAssertEqual(person.persistentChangedValues.count, 0)
            }
        }
    }
    
    func testChangesAfterPrimaryKeyChange() {
        // After reload, a record is not edited.
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                try person.insert(db)
                person.id = person.id + 1
                let changes = person.persistentChangedValues
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
                let changes = person.persistentChangedValues
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
    }
    
    func testCopyTransfersChanges() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let person = Person(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                XCTAssertEqual(person.copy().persistentChangedValues.count, 0)
                
                person.name = "Barbara"
                XCTAssertTrue(person.persistentChangedValues.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.persistentChangedValues.count, person.copy().persistentChangedValues.count)
                
                person.hasPersistentChangedValues = false
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                XCTAssertEqual(person.copy().persistentChangedValues.count, 0)
                
                person.hasPersistentChangedValues = true
                XCTAssertTrue(person.persistentChangedValues.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.persistentChangedValues.count, person.copy().persistentChangedValues.count)
            }
            try dbQueue.inDatabase { db in
                let person = PersonWithModifiedCaseColumns(name: "Arthur", age: 41)
                
                try person.insert(db)
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                XCTAssertEqual(person.copy().persistentChangedValues.count, 0)
                
                person.name = "Barbara"
                XCTAssertTrue(person.persistentChangedValues.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.persistentChangedValues.count, person.copy().persistentChangedValues.count)
                
                person.hasPersistentChangedValues = false
                XCTAssertEqual(person.persistentChangedValues.count, 0)
                XCTAssertEqual(person.copy().persistentChangedValues.count, 0)
                
                person.hasPersistentChangedValues = true
                XCTAssertTrue(person.persistentChangedValues.count > 0)            // TODO: compare actual changes
                XCTAssertEqual(person.persistentChangedValues.count, person.copy().persistentChangedValues.count)
            }
        }
    }
    
}
