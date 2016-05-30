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
    var creationDate: NSDate!
    
    init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: NSDate? = nil) {
        self.id = id
        self.name = name
        self.age = age
        self.creationDate = creationDate
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "creationDate TEXT NOT NULL, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        age = row.value(named: "age")
        name = row.value(named: "name")
        creationDate = row.value(named: "creationDate")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
            "creationDate": creationDate,
        ]
    }
    
    override func insert(db: Database) throws {
        // This is implicitely tested with the NOT NULL constraint on creationDate
        if creationDate == nil {
            creationDate = NSDate()
        }
        
        try super.insert(db)
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

private class MinimalPersonWithOverrides : Person {
    var extra: Int!
    
    // Record
    
    required init(_ row: Row) {
        extra = row.value(named: "extra")
        super.init(row)
    }
}

private class PersonWithOverrides : Person {
    enum SavingMethod {
        case Insert
        case Update
    }
    
    var extra: Int!
    var lastSavingMethod: SavingMethod?
    
    override init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: NSDate? = nil) {
        super.init(id: id, name: name, age: age, creationDate: creationDate)
    }
    
    // Record
    
    required init(_ row: Row) {
        extra = row.value(named: "extra")
        super.init(row)
    }
    
    override func insert(db: Database) throws {
        lastSavingMethod = .Insert
        try super.insert(db)
    }
    
    override func update(db: Database) throws {
        lastSavingMethod = .Update
        try super.update(db)
    }
}

class RecordSubClassTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setupInDatabase)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyCallsInsertMethod() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(name: "Arthur")
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(id: 123456, name: "Arthur")
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(name: "Arthur", age: 41)
                try record.insert(db)
                record.age = record.age! + 1
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Update)
            }
        }
    }
    
    func testSaveAfterDeleteCallsInsertMethod() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(name: "Arthur")
                try record.insert(db)
                try record.delete(db)
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelect() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let record = Person(name: "Arthur", age: 41)
                try record.insert(db)
                
                do {
                    let fetchedRecord = PersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertTrue(fetchedRecord.name == record.name)
                    XCTAssertTrue(fetchedRecord.age == record.age)
                    XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSinceDate(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                    XCTAssertTrue(fetchedRecord.extra == 123)
                }
                
                do {
                    let fetchedRecord = MinimalPersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                    XCTAssertTrue(fetchedRecord.id == record.id)
                    XCTAssertTrue(fetchedRecord.name == record.name)
                    XCTAssertTrue(fetchedRecord.age == record.age)
                    XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSinceDate(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                    XCTAssertTrue(fetchedRecord.extra == 123)
                }
            }
        }
    }
    
}
