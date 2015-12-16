import XCTest
import GRDB

class RecordWithoutPersistentDictionary : Record {
}

class SingleColumnRecord : Record {
    var name: String?
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

class DoubleColumnRecord : Record {
    var name: String?
    var age: Int?
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "age": age]
    }
}

class RecordDescriptionTests: GRDBTestCase {

    func testRecordWithoutPersistentDictionaryDescription() {
        let record = RecordWithoutPersistentDictionary()
        XCTAssertEqual(record.description, "<RecordWithoutPersistentDictionary>")
    }
    
    func testSimpleRecordDescription() {
        let record = SingleColumnRecord()
        record.name = "foo"
        XCTAssertEqual(record.description, "<SingleColumnRecord name:\"foo\">")
    }
    
    func testDoubleColumnRecordDescription() {
        let record = DoubleColumnRecord()
        record.name = "foo"
        record.age = 35
        XCTAssertTrue(["<DoubleColumnRecord name:\"foo\" age:35>", "<DoubleColumnRecord age:35 name:\"foo\">"].indexOf(record.description) != nil)
    }

}
