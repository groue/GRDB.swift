import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// I think those there is no double between those two, and this is the exact threshold:
private let maxInt64ConvertibleDouble = Double(9223372036854775295 as Int64)
private let minInt64NonConvertibleDouble = Double(9223372036854775296 as Int64)

// Not sure about the exact threshold
private let minInt64ConvertibleDouble = Double(Int64.min)
private let maxInt64NonConvertibleDouble: Double = -9.223372036854777e+18

// Not sure about the exact threshold
private let maxInt32ConvertibleDouble: Double = 2147483647.999999
private let minInt32NonConvertibleDouble: Double = 2147483648

// Not sure about the exact threshold
private let minInt32ConvertibleDouble: Double = -2147483648.999999
private let maxInt32NonConvertibleDouble: Double = -2147483649

class NumericOverflowTests: GRDBTestCase {

    func testHighInt64FromDoubleOverflows() {
        XCTAssertEqual(Int64.fromDatabaseValue(maxInt64ConvertibleDouble.databaseValue)!, 9223372036854774784)
        XCTAssertTrue(Int64.fromDatabaseValue((minInt64NonConvertibleDouble).databaseValue) == nil)
    }
    
    func testLowInt64FromDoubleOverflows() {
        XCTAssertEqual(Int64.fromDatabaseValue(minInt64ConvertibleDouble.databaseValue)!, Int64.min)
        XCTAssertTrue(Int64.fromDatabaseValue(maxInt64NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighInt32FromDoubleOverflows() {
        XCTAssertEqual(Int32.fromDatabaseValue(maxInt32ConvertibleDouble.databaseValue)!, Int32.max)
        XCTAssertTrue(Int32.fromDatabaseValue(minInt32NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowInt32FromDoubleOverflows() {
        XCTAssertEqual(Int32.fromDatabaseValue(minInt32ConvertibleDouble.databaseValue)!, Int32.min)
        XCTAssertTrue(Int32.fromDatabaseValue(maxInt32NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighIntFromDoubleOverflows() {
        #if arch(i386) || arch(arm)
            // 32 bits Int
            XCTAssertEqual(Int.fromDatabaseValue(maxInt32ConvertibleDouble.databaseValue)!, Int.max)
            XCTAssertTrue(Int.fromDatabaseValue(minInt32NonConvertibleDouble.databaseValue) == nil)
        #elseif arch(x86_64) || arch(arm64)
            // 64 bits Int
            XCTAssertEqual(Int64(Int.fromDatabaseValue(maxInt64ConvertibleDouble.databaseValue)!), 9223372036854774784)
            XCTAssertTrue(Int.fromDatabaseValue((minInt64NonConvertibleDouble).databaseValue) == nil)
        #else
            fatalError("Unknown architecture")
        #endif
    }
    
    func testLowIntFromDoubleOverflows() {
        #if arch(i386) || arch(arm)
            // 32 bits Int
            XCTAssertEqual(Int.fromDatabaseValue(minInt32ConvertibleDouble.databaseValue)!, Int.min)
            XCTAssertTrue(Int.fromDatabaseValue(maxInt32NonConvertibleDouble.databaseValue) == nil)
        #elseif arch(x86_64) || arch(arm64)
            // 64 bits Int
            XCTAssertEqual(Int.fromDatabaseValue(minInt64ConvertibleDouble.databaseValue)!, Int.min)
            XCTAssertTrue(Int.fromDatabaseValue(maxInt64NonConvertibleDouble.databaseValue) == nil)
        #else
            fatalError("Unknown architecture")
        #endif
    }
    
}
