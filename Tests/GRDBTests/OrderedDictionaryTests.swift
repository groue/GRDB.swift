import XCTest
@testable import GRDB

class OrderedDictionaryTests: GRDBTestCase {
    func testSubscriptWithDefaultValue() throws {
        var dict: OrderedDictionary<String, [String]> = [:]
        dict["a", default: []].append("foo")
        dict["a", default: []].append("bar")
        XCTAssertEqual(dict, ["a": ["foo", "bar"]])
    }
    
    func testMergingUniquingKeysWith() {
        do {
            let dict: OrderedDictionary = ["a": 1, "b": 2]
            
            let otherDictionary = ["a": 3, "c": 4]
            let otherOrderedDictionary: OrderedDictionary = ["a": 3, "c": 4]
            let otherSequence = zip(["a", "c"], [3, 4])
            
            do {
                let result = dict.merging(otherDictionary, uniquingKeysWith: { (current, _) in current })
                XCTAssertEqual(result, ["a": 1, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherOrderedDictionary, uniquingKeysWith: { (current, _) in current })
                XCTAssertEqual(result, ["a": 1, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherSequence, uniquingKeysWith: { (current, _) in current })
                XCTAssertEqual(result, ["a": 1, "b": 2, "c": 4])
            }
            
            do {
                let result = dict.merging(otherDictionary, uniquingKeysWith: { (_, new) in new })
                XCTAssertEqual(result, ["a": 3, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherOrderedDictionary, uniquingKeysWith: { (_, new) in new })
                XCTAssertEqual(result, ["a": 3, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherSequence, uniquingKeysWith: { (_, new) in new })
                XCTAssertEqual(result, ["a": 3, "b": 2, "c": 4])
            }
            
            do {
                let result = dict.merging(otherDictionary, uniquingKeysWith: { $0 + $1 })
                XCTAssertEqual(result, ["a": 4, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherOrderedDictionary, uniquingKeysWith: { $0 + $1 })
                XCTAssertEqual(result, ["a": 4, "b": 2, "c": 4])
            }
            do {
                let result = dict.merging(otherSequence, uniquingKeysWith: { $0 + $1 })
                XCTAssertEqual(result, ["a": 4, "b": 2, "c": 4])
            }
        }
    }
}
