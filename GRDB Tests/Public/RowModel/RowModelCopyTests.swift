import XCTest
import GRDB

class RowModelCopyTests: RowModelTestCase {
    
    func testRowModelCopyDatabaseValuesFrom() {
        let person1 = Person(id: 123, name: "Arthur", age: 41, creationDate: NSDate())
        let person2 = Person(id: 456, name: "Bobby")
        
        // Persons are different
        XCTAssertFalse(person2.id == person1.id)
        XCTAssertFalse(person2.name == person1.name)
        XCTAssertFalse((person1.age == nil) == (person2.age == nil))
        XCTAssertFalse((person1.creationDate == nil) == (person2.creationDate == nil))
        
        // And then identical
        person2.copyDatabaseValuesFrom(person1)
        XCTAssertTrue(person2.id == person1.id)
        XCTAssertTrue(person2.name == person1.name)
        XCTAssertTrue(person2.age == person1.age)
        XCTAssertTrue(abs(person2.creationDate.timeIntervalSinceDate(person1.creationDate)) < 1e-3)    // ISO-8601 is precise to the millisecond.
    }
}
