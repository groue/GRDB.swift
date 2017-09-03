import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationDataTests: GRDBTestCase {
    
    func testDatabaseValueOfEmptyData() {
        // Previous versions of GRDB would turn zero-length data into null
        // database values. Not any longer.
        let dbValue = Data().databaseValue
        XCTAssertFalse(dbValue.isNull)
    }
    
    func testDataDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: Data) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = Data.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to Data")
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(roundTrip(Data()))
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
