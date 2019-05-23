import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSStringTests: GRDBTestCase {
    
    func testNSStringDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSString) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSString.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSString(string: "")))
        XCTAssertTrue(try roundTrip(NSString(string: "foo")))
        XCTAssertTrue(try roundTrip(NSString(string: "'fooéı👨👨🏿🇫🇷🇨🇮'")))
    }
    
    func testNSStringDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSString) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = NSString.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSString")
                return false
            }
            return back.isEqual(value)
        }

        XCTAssertTrue(roundTrip(NSString(string: "")))
        XCTAssertTrue(roundTrip(NSString(string: "foo")))
        XCTAssertTrue(roundTrip(NSString(string: "'fooéı👨👨🏿🇫🇷🇨🇮'")))
    }
    
    func testNSStringFromStringDatabaseValueSuccess() {
        let databaseValue_String = "foo".databaseValue
        XCTAssertEqual(NSString.fromDatabaseValue(databaseValue_String), "foo")
    }
    
    func testNSStringFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSString.fromDatabaseValue(databaseValue_Double))
        XCTAssertEqual(NSString.fromDatabaseValue(databaseValue_Blob), "bar")
    }
    
}
