import XCTest
import GRDB

class MinimalPersonWithOverrides : Person {
    var extra: Int!
    
    // Record
    
    required init(_ row: Row) {
        extra = row.value(named: "extra")
        super.init(row)
    }
}

class PersonWithOverrides : Person {
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
    
    override func insert(db: DatabaseWriter) throws {
        lastSavingMethod = .Insert
        try super.insert(db)
    }
    
    override func update(db: DatabaseWriter) throws {
        lastSavingMethod = .Update
        try super.update(db)
    }
}

class RecordSubClassTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(name: "Arthur")
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let record = PersonWithOverrides(id: 123456, name: "Arthur")
                try record.save(db)
                XCTAssertEqual(record.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod() {
        assertNoError {
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
