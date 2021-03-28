import XCTest
import GRDB

class FoundationNSNumberTests: GRDBTestCase {
    
    func testNSNumberDatabaseValueToSwiftType() {
        enum Storage {
            case integer
            case double
        }
        
        func storage(_ n: NSNumber) -> Storage? {
            switch n.databaseValue.storage {
            case .int64:
                return .integer
            case .double:
                return .double
            default:
                return nil
            }
        }
        
        // case "c":
        do {
            let number = NSNumber(value: Int8.min + 1)
            XCTAssertEqual(String(cString: number.objCType), "c")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(Int8.min + 1))
        }
        
        // case "C":
        do {
            let number = NSNumber(value: UInt8.max - 1)
            // XCTAssertEqual(String(cString: number.objCType), "C") // get "s" instead of "C"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(UInt8.max - 1))
        }
        
        // case "s":
        do {
            let number = NSNumber(value: Int16.min + 1)
            XCTAssertEqual(String(cString: number.objCType), "s")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(Int16.min + 1))
        }
        
        // case "S":
        do {
            let number = NSNumber(value: UInt16.max - 1)
            // XCTAssertEqual(String(cString: number.objCType), "S") // get "i" instead of "S"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(UInt16.max - 1))
        }
        
        // case "i":
        do {
            let number = NSNumber(value: Int32.min + 1)
            XCTAssertEqual(String(cString: number.objCType), "i")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(Int32.min + 1))
        }
        
        // case "I":
        do {
            let number = NSNumber(value: UInt32.max - 1)
            // XCTAssertEqual(String(cString: number.objCType), "I") // get "q" instead of "I"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(UInt32.max - 1))
        }
        
        // case "l":
        do {
            let number = NSNumber(value: Int.min + 1)
            // XCTAssertEqual(String(cString: number.objCType), "l") // get "q" instead of "l"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(Int.min + 1))
        }
        
        // case "L":
        do {
            let number = NSNumber(value: UInt(UInt32.max))
            // XCTAssertEqual(String(cString: number.objCType), "L") // get "q" instead of "L"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(UInt32.max))
        }
        
        // case "q":
        do {
            let number = NSNumber(value: Int64.min + 1)
            XCTAssertEqual(String(cString: number.objCType), "q")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64(Int64.min + 1))
        }
        
        // case "Q":
        do {
            let number = NSNumber(value: UInt64(Int64.max))
            // XCTAssertEqual(String(cString: number.objCType), "Q") // get "q" instead of "Q"
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Int64.fromDatabaseValue(number.databaseValue), Int64.max)
        }
        
        // case "f":
        do {
            let number = NSNumber(value: Float(3))
            XCTAssertEqual(String(cString: number.objCType), "f")
            XCTAssertEqual(storage(number), .double)
            XCTAssertEqual(Float.fromDatabaseValue(number.databaseValue), Float(3))
        }
        
        // case "d":
        do {
            let number = NSNumber(value: 10.0)
            XCTAssertEqual(String(cString: number.objCType), "d")
            XCTAssertEqual(storage(number), .double)
            XCTAssertEqual(Double.fromDatabaseValue(number.databaseValue), 10.0)
        }
        
        // case "B":
        do {
            let number = NSNumber(value: true)
            XCTAssertEqual(String(cString: number.objCType), "c")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Bool.fromDatabaseValue(number.databaseValue), true)
        }
        
        do {
            let number = NSNumber(value: false)
            XCTAssertEqual(String(cString: number.objCType), "c")
            XCTAssertEqual(storage(number), .integer)
            XCTAssertEqual(Bool.fromDatabaseValue(number.databaseValue), false)
        }
    }
    
    func testNSNumberDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        func roundTrip(_ value: NSNumber) throws -> Bool {
            guard let back = try dbQueue.inDatabase({ try NSNumber.fetchOne($0, sql: "SELECT ?", arguments: [value]) }) else {
                XCTFail()
                return false
            }
            return back == value
        }
        
        XCTAssertTrue(try roundTrip(NSNumber(value: Int32.min + 1)))
        XCTAssertTrue(try roundTrip(NSNumber(value: Double(10000000.01))))
    }
    
    func testNSNumberDatabaseValueRoundTrip() {
        func roundTrip(_ value: NSNumber) -> Bool
        {
            let dbValue = value.databaseValue
            guard let back = NSNumber.fromDatabaseValue(dbValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSNumber")
                return false
            }
            return back.isEqual(to: value)
        }
        
        XCTAssertTrue(roundTrip(NSNumber(value: Int32.min + 1)))
        XCTAssertTrue(roundTrip(NSNumber(value: Double(10000000.01))))
    }
    
    func testNSNumberFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.null
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Blob = "bar".data(using: .utf8)!.databaseValue
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_Blob))
    }
    
    func testNSNumberDecodingFromText() throws {
        func test(_ value: String, isDecodedAs number: NSDecimalNumber) throws {
            let decodedFromDatabaseValue = NSNumber.fromDatabaseValue(value.databaseValue) as? NSDecimalNumber
            XCTAssertEqual(decodedFromDatabaseValue, number)

            let decodedFromDatabase = try DatabaseQueue().read { db in
                try NSNumber.fetchOne(db, sql: "SELECT ?", arguments: [value]) as? NSDecimalNumber
            }
            XCTAssertEqual(decodedFromDatabase, number)
        }
        try test("0", isDecodedAs: NSDecimalNumber(value: 0))
        try test("0.25", isDecodedAs: NSDecimalNumber(value: 0.25))
        try test("1", isDecodedAs: NSDecimalNumber(value: 1))
        try test("-1", isDecodedAs: NSDecimalNumber(value: -1))
        try test("9223372036854775807", isDecodedAs: NSDecimalNumber(value: 9223372036854775807))
        try test("9223372036854775806", isDecodedAs: NSDecimalNumber(value: 9223372036854775806))
        try test("-9223372036854775807", isDecodedAs: NSDecimalNumber(value: -9223372036854775807))
        try test("-9223372036854775808", isDecodedAs: NSDecimalNumber(value: -9223372036854775808))
        try test("18446744073709551615", isDecodedAs: NSDecimalNumber(value: UInt64(18446744073709551615)))
    }
}
