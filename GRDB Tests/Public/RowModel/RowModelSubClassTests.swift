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
        for (column, dbv) in row {
            switch column {
            case "extra": extra = dbv.value()
            default: break
            }
        }
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

class RowModelSubClassTests: RowModelTestCase {
    
    
    // MARK: - Save
    
    func testSaveWithNilPrimaryKeyCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur")
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    func testSaveWithNotNilPrimaryKeyThatDoesNotMatchAnyRowCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(id: 123456, name: "Arthur")
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    func testSaveWithNotNilPrimaryKeyThatMatchesARowCallsUpdateMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur", age: 41)
                try rowModel.insert(db)
                rowModel.age = rowModel.age! + 1
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Update)
            }
        }
    }
    
    func testSaveAfterDeleteCallsInsertMethod() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = PersonWithOverrides(name: "Arthur")
                try rowModel.insert(db)
                try rowModel.delete(db)
                try rowModel.save(db)
                XCTAssertEqual(rowModel.lastSavingMethod!, PersonWithOverrides.SavingMethod.Insert)
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelect() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Person(name: "Arthur", age: 41)
                try rowModel.insert(db)
                
                let fetchedRowModel = PersonWithOverrides.fetchOne(db, "SELECT *, 123 as extra FROM persons")!
                XCTAssertTrue(fetchedRowModel.id == rowModel.id)
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
                XCTAssertTrue(fetchedRowModel.age == rowModel.age)
                XCTAssertTrue(abs(fetchedRowModel.creationDate.timeIntervalSinceDate(rowModel.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
                XCTAssertTrue(fetchedRowModel.extra == 123)
            }
        }
    }
    
}
