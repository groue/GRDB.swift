import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class DataTests: GRDBTestCase {
    
    func testDatabaseValueCanNotStoreEmptyData() {
        // SQLite can't store zero-length blob.
        let databaseValue = Data().databaseValue
        XCTAssertEqual(databaseValue, DatabaseValue.null)
    }
    
    func testDataDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: Data) -> Bool
        {
            let databaseValue = value.databaseValue
            guard let back = Data.fromDatabaseValue(databaseValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to Data")
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(roundTrip("bar".data(using: .utf8)!))
    }
    
    func testDataFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "foo".databaseValue
        XCTAssertNil(Data.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(Data.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(Data.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(Data.fromDatabaseValue(databaseValue_String))
    }
}
