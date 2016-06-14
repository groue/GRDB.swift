import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSURLTests: GRDBTestCase {
    
    func testNSURLDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSURL) -> Bool
        {
            let databaseValue = value.databaseValue
            guard let back = NSURL.fromDatabaseValue(databaseValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSURL")
                return false
            }
            return back.isEqual(value)
        }
        
        XCTAssertTrue(roundTrip(NSURL(string: "https://github.com/groue/GRDB.swift")!))
        XCTAssertTrue(roundTrip(NSURL(fileURLWithPath: NSTemporaryDirectory())))
    }
    
    func testNSURLFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSURL.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSURL.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSURL.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(NSURL.fromDatabaseValue(databaseValue_Blob))
    }
    
}
