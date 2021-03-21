import XCTest
import GRDB

class FoundationNSDecimalNumberTests: GRDBTestCase {

    func testNSDecimalNumberPreservesIntegerValues() {
        
        enum Storage {
            case integer
            case double
        }
        
        func storage(_ n: NSDecimalNumber) -> Storage? {
            switch n.databaseValue.storage {
            case .int64:
                return .integer
            case .double:
                return .double
            default:
                return nil
            }
        }
        
        // Int64.max + 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775808")), .double)
        
        // Int64.max
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775807")), .integer)

        // Int64.max - 0.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775806.5")), .double)
        
        // Int64.max - 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775806")), .integer)
        
        // 0
        XCTAssertEqual(storage(NSDecimalNumber.zero), .integer)
        
        // 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "1")), .integer)
        XCTAssertEqual(storage(NSDecimalNumber(string: "1.0")), .integer)
        
        // 1.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "1.5")), .double)
        
        // Int64.min + 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807")), .integer)
        
        // Int64.min + 0.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807.5")), .double)
        
        // Int64.min
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775808")), .integer)
        
        // Int64.min - 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775809")), .double)
    }
    
    func testNSDecimalNumberDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSDecimalNumber) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSDecimalNumber.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSDecimalNumber(value: Int32.min + 1)))
        XCTAssertTrue(try roundTrip(NSDecimalNumber(value: Double(10000000.01))))
    }
    
    func testNSDecimalNumberDatabaseValueRoundTrip() {
        func roundTrip(_ value: NSDecimalNumber) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = NSDecimalNumber.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSDecimalNumber")
                return false
            }
            return back.isEqual(to: value)
        }
        
        XCTAssertTrue(roundTrip(NSDecimalNumber(value: Int32.min + 1)))
        XCTAssertTrue(roundTrip(NSDecimalNumber(value: Double(10000000.01))))
    }
    
    func testNSDecimalNumberFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSDecimalNumber.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSDecimalNumber.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSDecimalNumber.fromDatabaseValue(databaseValue_Blob))
    }
    
    func testNSDecimalNumberDecodingFromInt64() throws {
        func test(_ value: Int64, isDecodedAs number: NSDecimalNumber) throws {
            XCTAssertEqual(NSDecimalNumber(value: value), number)
            
            let decodedFromDatabaseValue = NSDecimalNumber.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)
            
            let decodedFromDatabase = try DatabaseQueue().read { db in
                try NSDecimalNumber.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test(0, isDecodedAs: NSDecimalNumber(string: "0"))
        try test(1, isDecodedAs: NSDecimalNumber(string: "1"))
        try test(-1, isDecodedAs: NSDecimalNumber(string: "-1"))
        try test(9223372036854775807, isDecodedAs: NSDecimalNumber(string: "9223372036854775807"))
        try test(9223372036854775806, isDecodedAs: NSDecimalNumber(string: "9223372036854775806"))
        try test(-9223372036854775807, isDecodedAs: NSDecimalNumber(string: "-9223372036854775807"))
        try test(-9223372036854775808, isDecodedAs: NSDecimalNumber(string: "-9223372036854775808"))
    }
    
    func testNSDecimalNumberDecodingFromDouble() throws {
        func test(_ value: Double, isDecodedAs number: NSDecimalNumber) throws {
            XCTAssertEqual(NSDecimalNumber(value: value), number)
            
            let decodedFromDatabaseValue = NSDecimalNumber.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)
            
            let decodedFromDatabase = try DatabaseQueue().read { db in
                try NSDecimalNumber.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test(0, isDecodedAs: NSDecimalNumber(string: "0"))
        try test(0.25, isDecodedAs: NSDecimalNumber(string: "0.25"))
        try test(1, isDecodedAs: NSDecimalNumber(string: "1"))
        try test(-1, isDecodedAs: NSDecimalNumber(string: "-1"))
    }
    
    func testNSDecimalNumberDecodingFromText() throws {
        func test(_ value: String, isDecodedAs number: NSDecimalNumber) throws {
            XCTAssertEqual(NSDecimalNumber(string: value), number)

            let decodedFromDatabaseValue = NSDecimalNumber.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)

            let decodedFromDatabase = try DatabaseQueue().read { db in
                try NSDecimalNumber.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test("0", isDecodedAs: NSDecimalNumber(string: "0"))
        try test("0.25", isDecodedAs: NSDecimalNumber(string: "0.25"))
        try test("1", isDecodedAs: NSDecimalNumber(string: "1"))
        try test("-1", isDecodedAs: NSDecimalNumber(string: "-1"))
        try test("9223372036854775807", isDecodedAs: NSDecimalNumber(string: "9223372036854775807"))
        try test("9223372036854775806", isDecodedAs: NSDecimalNumber(string: "9223372036854775806"))
        try test("-9223372036854775807", isDecodedAs: NSDecimalNumber(string: "-9223372036854775807"))
        try test("-9223372036854775808", isDecodedAs: NSDecimalNumber(string: "-9223372036854775808"))
        try test("18446744073709551615", isDecodedAs: NSDecimalNumber(string: "18446744073709551615"))
    }
}
