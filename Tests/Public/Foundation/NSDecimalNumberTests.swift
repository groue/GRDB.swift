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
            case Integer
            case Double
        }
        
        func storage(n: NSDecimalNumber) -> Storage? {
            switch n.databaseValue.storage {
            case .Int64:
                return .Integer
            case .Double:
                return .Double
            default:
                return nil
            }
        }
        
        // Int64.max + 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775808")), .Double)
        
        // Int64.max
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775807")), .Integer)

        // Int64.max - 0.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775806.5")), .Double)
        
        // Int64.max - 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "9223372036854775806")), .Integer)
        
        // 0
        XCTAssertEqual(storage(NSDecimalNumber.zero()), .Integer)
        
        // Int64.min + 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807")), .Integer)
        
        // Int64.min + 0.5
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775807.5")), .Double)
        
        // Int64.min
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775808")), .Integer)
        
        // Int64.min - 1
        XCTAssertEqual(storage(NSDecimalNumber(string: "-9223372036854775809")), .Double)
    }
}
