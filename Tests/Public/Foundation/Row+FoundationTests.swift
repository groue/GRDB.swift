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
        
        let dictionaryInvalidKeyType: NSDictionary = [NSNumber(integer: 1): "bar"]
        let row2 = Row(dictionaryInvalidKeyType)
        XCTAssertTrue(row2 == nil)
    }
    
    func testRowFromNSDictionary() {
        let dictionary: NSDictionary = ["a": "foo", "b": 1, "c": NSNull(), "d": NSDate(timeIntervalSince1970: 1443642439)]
        let row = Row(dictionary)!
        
        XCTAssertEqual(row.count, 4)
        XCTAssertEqual(row.value(named: "a") as String, "foo")
        XCTAssertEqual(row.value(named: "b") as Int, 1)
        XCTAssertTrue(row.databaseValue(named: "c")!.isNull)
        XCTAssertEqual(row.value(named: "d") as String, "2015-09-30 19:47:19.000")
    }
    
    func testRowToNSDictionary() {
        let row = Row(["a": "foo", "b": 1, "c": nil, "d": NSDate(timeIntervalSince1970: 1443642439)])
        let dictionary = row.toNSDictionary()
        XCTAssertEqual(dictionary.count, 4)
        XCTAssertTrue((dictionary["a"] as! NSString).isEqualToString("foo"))
        XCTAssertTrue((dictionary["b"] as! NSNumber).isEqualToNumber(NSNumber(integer: 1)))
        XCTAssertTrue(dictionary["c"] is NSNull)
        XCTAssertTrue((dictionary["d"] as! NSString).isEqualToString("2015-09-30 19:47:19.000"))
    }
}
