import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class RowFoundationTests: GRDBTestCase {

    func testRowFromInvalidDictionary() {
        let dictionary: [AnyHashable: Any] = ["a": NSObject()]
        let row = Row(dictionary)
        XCTAssertTrue(row == nil)
        
        let dictionaryInvalidKeyType: [AnyHashable: Any] = [NSNumber(value: 1): "bar"]
        let row2 = Row(dictionaryInvalidKeyType)
        XCTAssertTrue(row2 == nil)
    }
    
    func testRowFromDictionary() {
        let dictionary: [AnyHashable: Any] = ["a": "foo", "b": 1, "c": NSNull(), "d": NSDate(timeIntervalSince1970: 1443642439), "e": NSData(data: "foo".data(using: .utf8)!)]
        let row = Row(dictionary)!
        
        XCTAssertEqual(row.count, 5)
        XCTAssertEqual(row["a"] as String, "foo")
        XCTAssertEqual(row["b"] as Int, 1)
        XCTAssertTrue((row["c"] as DatabaseValue).isNull)
        XCTAssertEqual(row["d"] as String, "2015-09-30 19:47:19.000")
        XCTAssertEqual(row["e"] as Data, "foo".data(using: .utf8))
    }
}
