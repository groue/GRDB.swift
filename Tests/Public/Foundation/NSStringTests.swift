import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSStringTests: GRDBTestCase {
    
    func testNSStringDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSString) -> Bool
        {
            let databaseValue = value.databaseValue
            guard let back = NSString.fromDatabaseValue(databaseValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSString")
                return false
            }
            return back.isEqual(value)
        }

        XCTAssertTrue(roundTrip(NSString(string: "foo")))
    }
    
    func testNSStringFromStringDatabaseValueSuccess() {
        let databaseValue_String = "foo".databaseValue
        XCTAssertEqual(NSString.fromDatabaseValue(databaseValue_String), "foo")
    }
    
    func testNSNumberFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Blob))
    }
    
}
