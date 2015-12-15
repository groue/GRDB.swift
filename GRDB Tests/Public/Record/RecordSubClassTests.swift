import XCTest
import GRDB

class PersonWithOverrides : Person {
    enum SavingMethod {
        case Insert
        case Update
    }
    
    var extra: Int!
    var lastSavingMethod: SavingMethod?
    
    // Record
    
    override class func fromRow(row: Row) -> Self {
        let person = self.init(
            id: row.value(named: "id"),
            name: row.value(named: "name"),
            age: row.value(named: "age"),
            creationDate: row.value(named: "creationDate"))
        person.extra = row.value(named: "extra")
        return person
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
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", Person.setupInDatabase)
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
                
                let fetchedRecord = PersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRecord.id == record.id)
                XCTAssertTrue(fetchedRecord.name == record.name)
                XCTAssertTrue(fetchedRecord.age == record.age)
                XCTAssertTrue(abs(fetchedRecord.creationDate.timeIntervalSinceDate(record.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRecord.extra == 123)
            }
        }
    }
    
}
