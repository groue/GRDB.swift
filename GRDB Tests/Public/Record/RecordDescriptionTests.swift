import XCTest
import GRDB

class RecordWithoutPersistedDictionary : Record {
}

class SingleColumnRecord : Record {
    var name: String?
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

class DoubleColumnRecord : Record {
    var name: String?
    var age: Int?
    
    override var persistedDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "age": age]
    }
}

class RecordDescriptionTests: GRDBTestCase {

    func testRecordWithoutPersistedDictionaryDescription() {
        let record = RecordWithoutPersistedDictionary()
        XCTAssertEqual(record.description, "<RecordWithoutPersistedDictionary>")
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
