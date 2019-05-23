import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationURLTests: GRDBTestCase {
    
    func testURLDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: URL) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try URL.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(URL(string: "https://github.com/groue/GRDB.swift")!))
        XCTAssertTrue(try roundTrip(URL(fileURLWithPath: NSTemporaryDirectory())))
    }
    
    func testURLDatabaseValueRoundTrip() {
        
        func roundTrip(_ value: URL) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = URL.fromDatabaseValue(dbValue) else
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
        XCTAssertEqual(URL.fromDatabaseValue(databaseValue_Blob)!.absoluteString, "bar")
    }
    
}
