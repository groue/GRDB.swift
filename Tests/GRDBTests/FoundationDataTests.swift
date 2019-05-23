import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationDataTests: GRDBTestCase {
    
    func testDataDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: Data) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try Data.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(Data()))
        XCTAssertTrue(try roundTrip("bar".data(using: .utf8)!))
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
        XCTAssertEqual(Data.fromDatabaseValue(databaseValue_String), "foo".data(using: .utf8))
    }
}
