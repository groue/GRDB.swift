import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["age"] = age
        container["creationDate"] = creationDate
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

private class MinimalPersonWithOverrides : Person {
    var extra: Int!
    
    // Record
    
    required init(row: Row) {
        extra = row.value(named: "extra")
        super.init(row: row)
    }
}

private class PersonWithOverrides : Person {
    enum SavingMethod {
        case insert
        case update
    }
    
    var extra: Int!
    var lastSavingMethod: SavingMethod?
    
    override init(id: Int64? = nil, name: String? = nil, age: Int? = nil, creationDate: Date? = nil) {
        super.init(id: id, name: name, age: age, creationDate: creationDate)
    }
    
    // Record
    
    required init(row: Row) {
        extra = row.value(named: "extra")
        super.init(row: row)
    }
    
    override func insert(_ db: Database) throws {
        lastSavingMethod = .insert
        try super.insert(db)
    }
    
    override func update(_ db: Database, columns: Set<String>) throws {
        lastSavingMethod = .update
        try super.update(db, columns: columns)
    }
}

class RecordSubClassTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setup)
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyCallsInsertMethod() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PersonWithOverrides(name: "Arthur")
            try record.save(db)
            XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.insert)
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PersonWithOverrides(id: 123456, name: "Arthur")
            try record.save(db)
            XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.insert)
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PersonWithOverrides(name: "Arthur", age: 41)
            try record.insert(db)
            record.age = record.age! + 1
            try record.save(db)
            XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.update)
        }
    }
    
    func testSaveAfterDeleteCallsInsertMethod() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = PersonWithOverrides(name: "Arthur")
            try record.insert(db)
            try record.delete(db)
            try record.save(db)
            XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.insert)
        }
    }
    
    
    // MARK: - Select
    
    func testSelect() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = Person(name: "Arthur", age: 41)
            try record.insert(db)
            
            do {
                let fetchedRecord = try PersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRecord.extra == 123)
            }
            
            do {
                let fetchedRecord = try MinimalPersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRecord.extra == 123)
            }
        }
    }
}
