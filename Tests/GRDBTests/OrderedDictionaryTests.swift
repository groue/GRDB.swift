import XCTest
@testable import GRDB

class OrderedDictionaryTests: GRDBTestCase {
    func testSubscriptWithDefaultValue() throws {
        var dict: OrderedDictionary<String, [String]> = [:]
        dict["a", default: []].append("foo")
        dict["a", default: []].append("bar")
        XCTAssertEqual(dict, ["a": ["foo", "bar"]])
    }
}
