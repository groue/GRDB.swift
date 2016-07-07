import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSDecimalNumberTests: GRDBTestCase {

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
}
