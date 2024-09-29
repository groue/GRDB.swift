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
    
    static func setup(_ db: Database) throws {
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
        id = row["id"]
        age = row["age"]
        name = row["name"]
        creationDate = row["creationDate"]
        try super.init(row: row)
    }
    
    override func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["name"] = name
        container["age"] = age
        container["creationDate"] = creationDate
    }
    
    override func willInsert(_ db: Database) throws {
        if creationDate == nil {
            creationDate = Date()
        }
        try super.willInsert(db)
    }
    
    override func didInsert(_ inserted: InsertionSuccess) {
        super.didInsert(inserted)
        id = inserted.rowID
    }
}

private class MinimalPersonWithOverrides : Person {
    var extra: Int!
    
    // Record
    
    required init(row: Row) throws {
        extra = row["extra"]
        try super.init(row: row)
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
    
    required init(row: Row) throws {
        extra = row["extra"]
        try super.init(row: row)
    }
    
    override func willInsert(_ db: Database) throws {
        lastSavingMethod = .insert
        try super.willInsert(db)
    }
    
    override func willUpdate(_ db: Database, columns: Set<String>) throws {
        lastSavingMethod = .update
        try super.willUpdate(db, columns: columns)
    }
}

class RecordSubClassTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson") {
            try Person.setup($0)
        }
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
                let fetchedRecord = try PersonWithOverrides.fetchOne(db, sql: "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRecord.extra == 123)
            }
            
            do {
                let fetchedRecord = try MinimalPersonWithOverrides.fetchOne(db, sql: "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSince(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRecord.extra == 123)
            }
        }
    }
}
