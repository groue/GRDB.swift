import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class UUIDTests: GRDBTestCase {
    
    func testUUIDDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: UUID) -> Bool {
            let databaseValue = value.databaseValue
            guard let back = UUID.fromDatabaseValue(databaseValue) else {
                XCTFail("Failed to convert from DatabaseValue to UUID")
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(roundTrip(UUID(uuidString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!))
        XCTAssertTrue(roundTrip(UUID()))
    }
    
    func testUUIDFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "56e7d8d3-e9e4-48b6-968e-8d102833af00".databaseValue
        let databaseValue_badBlob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(UUID.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(UUID.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(UUID.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(UUID.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(UUID.fromDatabaseValue(databaseValue_badBlob))
    }
    
}
