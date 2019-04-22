import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSDataTests: GRDBTestCase {
    
    func testNSDataDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSData) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSData.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSData(data: "bar".data(using: .utf8)!)))
        XCTAssertTrue(try roundTrip(NSData()))
    }
    
    func testNSDataDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSData) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = NSData.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSData")
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(roundTrip(NSData(data: "bar".data(using: .utf8)!)))
        XCTAssertTrue(roundTrip(NSData()))
    }
    
    func testNSDataFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "foo".databaseValue
        XCTAssertNil(NSData.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSData.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSData.fromDatabaseValue(databaseValue_Double))
        XCTAssertEqual(NSData.fromDatabaseValue(databaseValue_String)! as Data, "foo".data(using: .utf8))
    }
}
