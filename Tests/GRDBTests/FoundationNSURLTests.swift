import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSURLTests: GRDBTestCase {
    
    func testNSURLDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSURL) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSURL.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSURL(string: "https://github.com/groue/GRDB.swift")!))
        XCTAssertTrue(try roundTrip(NSURL(fileURLWithPath: NSTemporaryDirectory())))
    }
    
    func testNSURLDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: NSURL) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = NSURL.fromDatabaseValue(dbValue) else
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
        XCTAssertEqual(NSURL.fromDatabaseValue(databaseValue_Blob)!.absoluteString, "bar")
    }
    
}
