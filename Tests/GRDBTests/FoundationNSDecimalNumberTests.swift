import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

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
        
        // Int64.min + 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807")), .integer)
        
        // Int64.min + 0.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807.5")), .double)
        
        // Int64.min
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775808")), .integer)
        
        // Int64.min - 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775809")), .double)
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
    
    // TODO: uncomment, make it work, add tests for failure cases
//    func testNSDecimalNumberDecodingFromText() throws {
//        func test(_ value: String, isDecodedAs number: NSDecimalNumber) throws {
//            XCTAssertEqual(NSDecimalNumber(string: value), number)
//
//            let decodedFromDatabaseValue = NSDecimalNumber.fromDatabaseValue(value.databaseValue)
//            XCTAssertEqual(decodedFromDatabaseValue, number)
//
//            let decodedFromDatabase = try DatabaseQueue().read { db in
//                try NSDecimalNumber.fetchOne(db, sql: "SELECT ?", arguments: [value])
//            }
//            XCTAssertEqual(decodedFromDatabase, number)
//        }
//        try test("0", isDecodedAs: NSDecimalNumber(string: "0"))
//        try test("0.25", isDecodedAs: NSDecimalNumber(string: "0.25"))
//        try test("1", isDecodedAs: NSDecimalNumber(string: "1"))
//        try test("-1", isDecodedAs: NSDecimalNumber(string: "-1"))
//        try test("9223372036854775807", isDecodedAs: NSDecimalNumber(string: "9223372036854775807"))
//        try test("9223372036854775806", isDecodedAs: NSDecimalNumber(string: "9223372036854775806"))
//        try test("-9223372036854775807", isDecodedAs: NSDecimalNumber(string: "-9223372036854775807"))
//        try test("-9223372036854775808", isDecodedAs: NSDecimalNumber(string: "-9223372036854775808"))
//    }
}
