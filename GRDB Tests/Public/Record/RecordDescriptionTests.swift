import XCTest
import GRDB

class RecordWithoutStoredDatabaseDictionary : Record {
}

class SingleColumnRecord : Record {
    var name: String?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

class DoubleColumnRecord : Record {
    var name: String?
    var age: Int?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "age": age]
    }
}

class RecordDescriptionTests: GRDBTestCase {

    func testRecordWithoutStoredDatabaseDictionaryDescription() {
        let record = RecordWithoutStoredDatabaseDictionary()
        XCTAssertEqual(record.description, "<RecordWithoutStoredDatabaseDictionary>")
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
