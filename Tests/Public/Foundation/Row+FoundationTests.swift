import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class RowFoundationTests: GRDBTestCase {

    func testRowFromInvalidNSDictionary() {
        let dictionary: NSDictionary = ["a": NSObject()]
        let row = Row(dictionary)
        XCTAssertTrue(row == nil)
        
        let dictionaryInvalidKeyType: NSDictionary = [NSNumber(value: 1): "bar"]
        let row2 = Row(dictionaryInvalidKeyType)
        XCTAssertTrue(row2 == nil)
    }
    
    func testRowFromNSDictionary() {
        let dictionary: NSDictionary = ["a": "foo", "b": 1, "c": NSNull(), "d": NSDate(timeIntervalSince1970: 1443642439), "e": NSData(data: "foo".data(using: .utf8)!)]
        let row = Row(dictionary)!
        
        XCTAssertEqual(row.count, 5)
        XCTAssertEqual(row.value(named: "a") as String, "foo")
        XCTAssertEqual(row.value(named: "b") as Int, 1)
        XCTAssertTrue(row.databaseValue(named: "c")!.isNull)
        XCTAssertEqual(row.value(named: "d") as String, "2015-09-30 19:47:19.000")
        XCTAssertEqual(row.value(named: "e") as Data, "foo".data(using: .utf8))
    }
    
    func testRowToNSDictionary() {
        let data = "foo".data(using: .utf8)!
        let row = Row(["a": "foo", "b": 1, "c": nil, "d": Date(timeIntervalSince1970: 1443642439), "e": data])
        let dictionary = row.toNSDictionary()
        XCTAssertEqual(dictionary.count, 5)
        XCTAssertTrue((dictionary["a"] as! NSString).isEqual(to: "foo"))
        XCTAssertTrue((dictionary["b"] as! NSNumber).isEqual(to: NSNumber(value: 1)))
        XCTAssertTrue(dictionary["c"] is NSNull)
        XCTAssertTrue((dictionary["d"] as! NSString).isEqual(to: "2015-09-30 19:47:19.000"))
        XCTAssertTrue((dictionary["e"] as! NSData).isEqual(to: "foo".data(using: .utf8)!))
    }
}
