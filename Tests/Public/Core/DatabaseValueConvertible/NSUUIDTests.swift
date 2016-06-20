import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSUUIDTests: GRDBTestCase {
    
    func testNSUUIDDatabaseValueRoundTrip() {
        
        func roundTrip(value: NSUUID) -> Bool {
            let databaseValue = value.databaseValue
            guard let back = NSUUID.fromDatabaseValue(databaseValue) else {
                XCTFail("Failed to convert from DatabaseValue to NSUUID")
                return false
            }
            return back.isEqual(value)
        }
        
        XCTAssertTrue(roundTrip(NSUUID(UUIDString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!))
    }
    
    func testNSUUIDFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.Null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "56e7d8d3-e9e4-48b6-968e-8d102833af00".databaseValue
        let databaseValue_badBlob = "bar".dataUsingEncoding(NSUTF8StringEncoding)!.databaseValue
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_badBlob))
    }
    
}
