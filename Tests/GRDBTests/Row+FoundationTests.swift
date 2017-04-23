import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
        XCTAssertEqual(row.value(named: "a") as String, "foo")
        XCTAssertEqual(row.value(named: "b") as Int, 1)
        XCTAssertTrue((row.value(named: "c") as DatabaseValue).isNull)
        XCTAssertEqual(row.value(named: "d") as String, "2015-09-30 19:47:19.000")
        XCTAssertEqual(row.value(named: "e") as Data, "foo".data(using: .utf8))
    }
}
