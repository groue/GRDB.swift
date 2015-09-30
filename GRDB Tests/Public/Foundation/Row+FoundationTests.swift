import XCTest
import GRDB

class Row_FoundationTests: GRDBTestCase {

    func testRowFromNSDictionary() {
        let dictionary = ["a": "foo", "b": 1, "c": NSNull()]
        let row = Row(dictionary: dictionary)
        
        XCTAssertEqual(row.count, 3)
        XCTAssertEqual(row.value(named: "a") as String, "foo")
        XCTAssertEqual(row.value(named: "b") as Int, 1)
        XCTAssertTrue(row.value(named: "c") == nil)
    }
    
    func testRowToNSDictionary() {
        let row = Row(dictionary: ["a": "foo", "b": 1, "c": nil])
        let dictionary = row.toDictionary()
        XCTAssertEqual(dictionary.count, 3)
        XCTAssertTrue((dictionary["a"] as! NSString).isEqualToString("foo"))
        XCTAssertTrue((dictionary["b"] as! NSNumber).isEqualToNumber(NSNumber(integer: 1)))
        XCTAssertTrue(dictionary["c"] is NSNull)
    }
}
