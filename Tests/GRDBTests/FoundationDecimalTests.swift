import XCTest
import GRDB

class FoundationDecimalTests: GRDBTestCase {
    
    func testDecimalIsEncodedAsString() throws {
        XCTAssertEqual(Decimal(string: "0")!.databaseValue, "0".databaseValue)
        XCTAssertEqual(Decimal(string: "0.5")!.databaseValue, "0.5".databaseValue)
        XCTAssertEqual(Decimal(string: "1")!.databaseValue, "1".databaseValue)
        XCTAssertEqual(Decimal(string: "-1")!.databaseValue, "-1".databaseValue)
        XCTAssertEqual(Decimal(string: "9223372036854775807")!.databaseValue, "9223372036854775807".databaseValue)
        XCTAssertEqual(Decimal(string: "9223372036854775806")!.databaseValue, "9223372036854775806".databaseValue)
        XCTAssertEqual(Decimal(string: "-9223372036854775807")!.databaseValue, "-9223372036854775807".databaseValue)
        XCTAssertEqual(Decimal(string: "-9223372036854775808")!.databaseValue, "-9223372036854775808".databaseValue)
        XCTAssertEqual(Decimal(string: "18446744073709551615")!.databaseValue, "18446744073709551615".databaseValue)
    }

    func testDecimalDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: Decimal) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try Decimal.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(Decimal(Int32.min + 1)))
        XCTAssertTrue(try roundTrip(Decimal(Double(10000000.01))))
    }
    
    func testDecimalDatabaseValueRoundTrip() {
        func roundTrip(_ value: Decimal) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = Decimal.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to Decimal")
                return false
            }
            return back.isEqual(to: value)
        }
        
        XCTAssertTrue(roundTrip(Decimal(Int32.min + 1)))
        XCTAssertTrue(roundTrip(Decimal(Double(10000000.01))))
    }
    
    func testDecimalFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(Decimal.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(Decimal.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(Decimal.fromDatabaseValue(databaseValue_Blob))
    }

    func testDecimalDecodingFromInt64() throws {
        func test(_ value: Int64, isDecodedAs number: Decimal) throws {
            XCTAssertEqual(Decimal(value), number)
            
            let decodedFromDatabaseValue = Decimal.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)
            
            let decodedFromDatabase = try DatabaseQueue().read { db in
                try Decimal.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test(0, isDecodedAs: Decimal(string: "0")!)
        try test(1, isDecodedAs: Decimal(string: "1")!)
        try test(-1, isDecodedAs: Decimal(string: "-1")!)
        try test(9223372036854775807, isDecodedAs: Decimal(string: "9223372036854775807")!)
        try test(9223372036854775806, isDecodedAs: Decimal(string: "9223372036854775806")!)
        try test(-9223372036854775807, isDecodedAs: Decimal(string: "-9223372036854775807")!)
        try test(-9223372036854775808, isDecodedAs: Decimal(string: "-9223372036854775808")!)
    }
    
    func testDecimalDecodingFromDouble() throws {
        func test(_ value: Double, isDecodedAs number: Decimal) throws {
            XCTAssertEqual(Decimal(value), number)
            
            let decodedFromDatabaseValue = Decimal.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)
            
            let decodedFromDatabase = try DatabaseQueue().read { db in
                try Decimal.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test(0, isDecodedAs: Decimal(string: "0")!)
        try test(0.25, isDecodedAs: Decimal(string: "0.25")!)
        try test(1, isDecodedAs: Decimal(string: "1")!)
        try test(-1, isDecodedAs: Decimal(string: "-1")!)
    }
    
    func testDecimalDecodingFromText() throws {
        func test(_ value: String, isDecodedAs number: Decimal) throws {
            XCTAssertEqual(Decimal(string: value), number)

            let decodedFromDatabaseValue = Decimal.fromDatabaseValue(value.databaseValue)
            XCTAssertEqual(decodedFromDatabaseValue, number)

            let decodedFromDatabase = try DatabaseQueue().read { db in
                try Decimal.fetchOne(db, sql: "SELECT ?", arguments: [value])
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test("0", isDecodedAs: Decimal(string: "0")!)
        try test("0.25", isDecodedAs: Decimal(string: "0.25")!)
        try test("1", isDecodedAs: Decimal(string: "1")!)
        try test("-1", isDecodedAs: Decimal(string: "-1")!)
        try test("9223372036854775807", isDecodedAs: Decimal(string: "9223372036854775807")!)
        try test("9223372036854775806", isDecodedAs: Decimal(string: "9223372036854775806")!)
        try test("-9223372036854775807", isDecodedAs: Decimal(string: "-9223372036854775807")!)
        try test("-9223372036854775808", isDecodedAs: Decimal(string: "-9223372036854775808")!)
        try test("18446744073709551615", isDecodedAs: Decimal(string: "18446744073709551615")!)
    }
}
