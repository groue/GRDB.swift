import XCTest
import GRDB

class RecordCopyTests: RecordTestCase {
    
    func testRecordCopy() {
        let person1 = Person(id: 123, name: "Arthur", age: 41, creationDate: NSDate())
        let person2 = person1.copy()
        XCTAssertTrue(person2.id == person1.id)
        XCTAssertTrue(person2.name == person1.name)
        XCTAssertTrue(person2.age == person1.age)
        XCTAssertTrue(abs(person2.creationDate.timeIntervalSinceDate(person1.creationDate)) < 1e-3)
    }
}
