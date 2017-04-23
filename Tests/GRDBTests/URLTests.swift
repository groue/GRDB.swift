import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class URLTests: GRDBTestCase {
    
    func testURLDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: URL) -> Bool
        {
            let databaseValue = value.databaseValue
            guard let back = URL.fromDatabaseValue(databaseValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to URL")
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(roundTrip(URL(string: "https://github.com/groue/GRDB.swift")!))
        XCTAssertTrue(roundTrip(URL(fileURLWithPath: NSTemporaryDirectory())))
    }
    
    func testURLFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(URL.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(URL.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(URL.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(URL.fromDatabaseValue(databaseValue_Blob))
    }
    
}
