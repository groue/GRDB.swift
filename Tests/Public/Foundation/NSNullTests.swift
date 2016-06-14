import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSNullTests: GRDBTestCase {
    
    func testNSNullFromDatabaseValue() {
        // NSNull.fromDatabaseValue always returns nil?
        let databaseValue = DatabaseValue.null
        XCTAssertNil(NSNull.fromDatabaseValue(databaseValue))
    }
    
    func testNSNullFromDatabaseValueFailure() {
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSNull.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSNull.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(NSNull.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSNull.fromDatabaseValue(databaseValue_Blob))
    }
    
}
