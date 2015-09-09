import XCTest
import GRDB

class RowModelWithoutStoredDatabaseDictionary : RowModel {
}

class SingleColumnRowModel : RowModel {
    var name: String?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
}

class DoubleColumnRowModel : RowModel {
    var name: String?
    var age: Int?
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name, "age": age]
    }
}

class RowModelDescriptionTests: RowModelTestCase {

    func testRowModelWithoutStoredDatabaseDictionaryDescription() {
        let model = RowModelWithoutStoredDatabaseDictionary()
        XCTAssertEqual(model.description, "<RowModelWithoutStoredDatabaseDictionary>")
    }
    
    func testSimpleRowModelDescription() {
        let model = SingleColumnRowModel()
        model.name = "foo"
        XCTAssertEqual(model.description, "<SingleColumnRowModel name:\"foo\">")
    }
    
    func testDoubleColumnRowModelDescription() {
        let model = DoubleColumnRowModel()
        model.name = "foo"
        model.age = 35
        XCTAssertTrue(["<DoubleColumnRowModel name:\"foo\" age:35>", "<DoubleColumnRowModel age:35 name:\"foo\">"].indexOf(model.description) != nil)
    }

}
