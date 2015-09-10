import XCTest
import GRDB

class PersonWithOverrides: Person {
    enum SavingMethod {
        case Insert
        case Update
    }
    
    var extra: Int!
    var lastSavingMethod: SavingMethod?
    
    override func updateFromRow(row: Row) {
        if let dbv = row["extra"] { extra = dbv.value() }
        super.updateFromRow(row) // Subclasses are required to call super.
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

class RecordSubClassTests: RecordTestCase {
    
    
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
