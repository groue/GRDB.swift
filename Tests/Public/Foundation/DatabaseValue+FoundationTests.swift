import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DatabaseValueFoundationTests: GRDBTestCase {
    
    func testDatabaseValueToAnyObject() {
        let testValue_Int64: Int64 = Int64(1)
        let testValue_Double: Double = Double(100000.1)
        let testValue_String: String = "foo"
        let testValue_Data: NSData = "bar".dataUsingEncoding(NSUTF8StringEncoding)!
        
        let databaseValue_Null = DatabaseValue.Null
        let databaseValue_Int64 = testValue_Int64.databaseValue
        let databaseValue_Double = testValue_Double.databaseValue
        let databaseValue_String = testValue_String.databaseValue
        let databaseValue_Blob = testValue_Data.databaseValue
        
        let anyObject_Null = databaseValue_Null.toAnyObject()
        let anyObject_Int64 = databaseValue_Int64.toAnyObject()
        let anyObject_Double = databaseValue_Double.toAnyObject()
        let anyObject_String = databaseValue_String.toAnyObject()
        let anyObject_Blob = databaseValue_Blob.toAnyObject()
        
        XCTAssertTrue(anyObject_Null is NSNull)
        XCTAssertEqual(anyObject_Null as? NSNull, NSNull())
        XCTAssertTrue(anyObject_Int64 is NSNumber)
        XCTAssertEqual(anyObject_Int64 as? NSNumber, NSNumber(longLong: testValue_Int64))
        XCTAssertTrue(anyObject_Double is NSNumber)
        XCTAssertEqual(anyObject_Double as? NSNumber, NSNumber(double: Double(100000.1)))
        XCTAssertTrue(anyObject_String is NSString)
        XCTAssertEqual(anyObject_String as? NSString, testValue_String)
        XCTAssertTrue(anyObject_Blob is NSData)
        XCTAssertEqual(anyObject_Blob as? NSData, testValue_Data)
    }
}
