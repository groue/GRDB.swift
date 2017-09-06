import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSUUIDTests: GRDBTestCase {
    
    func testNSUUIDDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSUUID) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSUUID.fetchOne($0, "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSUUID(uuidString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!))
        XCTAssertTrue(try roundTrip(NSUUID()))
    }
    
    func testNSUUIDDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSUUID) -> Bool {
            let dbValue = value.databaseValue
            guard let back = NSUUID.fromDatabaseValue(dbValue) else {
                XCTFail("Failed to convert from DatabaseValue to NSUUID")
                return false
            }
            return back.isEqual(value)
        }
        
        XCTAssertTrue(roundTrip(NSUUID(uuidString: "56e7d8d3-e9e4-48b6-968e-8d102833af00")!))
        XCTAssertTrue(roundTrip(NSUUID()))
    }
    
    func testNSUUIDFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_Int64 = Int64(1).databaseValue
        let databaseValue_Double = Double(100000.1).databaseValue
        let databaseValue_String = "56e7d8d3-e9e4-48b6-968e-8d102833af00".databaseValue
        let databaseValue_badBlob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Int64))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_Double))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSUUID.fromDatabaseValue(databaseValue_badBlob))
    }
    
}
