import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private let maxInt64ConvertibleDouble = Double(9223372036854775295 as Int64)
private let minInt64NonConvertibleDouble = Double(9223372036854775296 as Int64)

private let minInt64ConvertibleDouble = Double(Int64.min)
private let maxInt64NonConvertibleDouble: Double = -9.223372036854777e+18

private let maxInt32ConvertibleDouble: Double = 2147483647.999999
private let minInt32NonConvertibleDouble: Double = 2147483648

private let minInt32ConvertibleDouble: Double = -2147483648.999999
private let maxInt32NonConvertibleDouble: Double = -2147483649

private let maxInt16ConvertibleDouble: Double = 32767.999999
private let minInt16NonConvertibleDouble: Double = 32768

private let minInt16ConvertibleDouble: Double = -32768.999999
private let maxInt16NonConvertibleDouble: Double = -32769

private let maxInt8ConvertibleDouble: Double = 127.999999
private let minInt8NonConvertibleDouble: Double = 128

private let minInt8ConvertibleDouble: Double = -128.999999
private let maxInt8NonConvertibleDouble: Double = -129

private let maxUInt64ConvertibleDouble = Double(9223372036854775295 as UInt64)
private let minUInt64NonConvertibleDouble = Double(9223372036854775296 as Int64)

private let minUInt64ConvertibleDouble: Double = 0.0
private let maxUInt64NonConvertibleDouble: Double = -1.0

private let maxUInt32ConvertibleDouble: Double = 4294967295
private let minUInt32NonConvertibleDouble: Double = 4294967296

private let minUInt32ConvertibleDouble: Double = 0.0
private let maxUInt32NonConvertibleDouble: Double = -1.0

private let maxUInt16ConvertibleDouble: Double = 65535
private let minUInt16NonConvertibleDouble: Double = 65536

private let minUInt16ConvertibleDouble: Double = 0.0
private let maxUInt16NonConvertibleDouble: Double = -1.0

private let maxUInt8ConvertibleDouble: Double = 255
private let minUInt8NonConvertibleDouble: Double = 256

private let minUInt8ConvertibleDouble: Double = 0.0
private let maxUInt8NonConvertibleDouble: Double = -1.0

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
    
    func testHighInt16FromDoubleOverflows() {
        XCTAssertEqual(Int16.fromDatabaseValue(maxInt16ConvertibleDouble.databaseValue)!, Int16.max)
        XCTAssertTrue(Int16.fromDatabaseValue(minInt16NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowInt16FromDoubleOverflows() {
        XCTAssertEqual(Int16.fromDatabaseValue(minInt16ConvertibleDouble.databaseValue)!, Int16.min)
        XCTAssertTrue(Int16.fromDatabaseValue(maxInt16NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighInt8FromDoubleOverflows() {
        XCTAssertEqual(Int8.fromDatabaseValue(maxInt8ConvertibleDouble.databaseValue)!, Int8.max)
        XCTAssertTrue(Int8.fromDatabaseValue(minInt8NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowInt8FromDoubleOverflows() {
        XCTAssertEqual(Int8.fromDatabaseValue(minInt8ConvertibleDouble.databaseValue)!, Int8.min)
        XCTAssertTrue(Int8.fromDatabaseValue(maxInt8NonConvertibleDouble.databaseValue) == nil)
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
    
    func testHighUInt64FromDoubleOverflows() {
        XCTAssertEqual(UInt64.fromDatabaseValue(maxUInt64ConvertibleDouble.databaseValue)!, 9223372036854774784)
        XCTAssertTrue(UInt64.fromDatabaseValue((minUInt64NonConvertibleDouble).databaseValue) == nil)
    }
    
    func testLowUInt64FromDoubleOverflows() {
        XCTAssertEqual(UInt64.fromDatabaseValue(minUInt64ConvertibleDouble.databaseValue)!, UInt64.min)
        XCTAssertTrue(UInt64.fromDatabaseValue(maxUInt64NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighUInt32FromDoubleOverflows() {
        XCTAssertEqual(UInt32.fromDatabaseValue(maxUInt32ConvertibleDouble.databaseValue)!, UInt32.max)
        XCTAssertTrue(UInt32.fromDatabaseValue(minUInt32NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowUInt32FromDoubleOverflows() {
        XCTAssertEqual(UInt32.fromDatabaseValue(minUInt32ConvertibleDouble.databaseValue)!, UInt32.min)
        XCTAssertTrue(UInt32.fromDatabaseValue(maxUInt32NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighUInt16FromDoubleOverflows() {
        XCTAssertEqual(UInt16.fromDatabaseValue(maxUInt16ConvertibleDouble.databaseValue)!, UInt16.max)
        XCTAssertTrue(UInt16.fromDatabaseValue(minUInt16NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowUInt16FromDoubleOverflows() {
        XCTAssertEqual(UInt16.fromDatabaseValue(minUInt16ConvertibleDouble.databaseValue)!, UInt16.min)
        XCTAssertTrue(UInt16.fromDatabaseValue(maxUInt16NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighUInt8FromDoubleOverflows() {
        XCTAssertEqual(UInt8.fromDatabaseValue(maxUInt8ConvertibleDouble.databaseValue)!, UInt8.max)
        XCTAssertTrue(UInt8.fromDatabaseValue(minUInt8NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testLowUInt8FromDoubleOverflows() {
        XCTAssertEqual(UInt8.fromDatabaseValue(minUInt8ConvertibleDouble.databaseValue)!, UInt8.min)
        XCTAssertTrue(UInt8.fromDatabaseValue(maxUInt8NonConvertibleDouble.databaseValue) == nil)
    }
    
    func testHighUIntFromDoubleOverflows() {
        #if arch(i386) || arch(arm)
            // 32 bits UInt
            XCTAssertEqual(UInt.fromDatabaseValue(maxUInt32ConvertibleDouble.databaseValue)!, UInt.max)
            XCTAssertTrue(UInt.fromDatabaseValue(minUInt32NonConvertibleDouble.databaseValue) == nil)
        #elseif arch(x86_64) || arch(arm64)
            // 64 bits UInt
            XCTAssertEqual(UInt64(UInt.fromDatabaseValue(maxUInt64ConvertibleDouble.databaseValue)!), 9223372036854774784)
            XCTAssertTrue(UInt.fromDatabaseValue((minUInt64NonConvertibleDouble).databaseValue) == nil)
        #else
            fatalError("Unknown architecture")
        #endif
    }
    
    func testLowUIntFromDoubleOverflows() {
        #if arch(i386) || arch(arm)
            // 32 bits UInt
            XCTAssertEqual(UInt.fromDatabaseValue(minUInt32ConvertibleDouble.databaseValue)!, UInt.min)
            XCTAssertTrue(UInt.fromDatabaseValue(maxUInt32NonConvertibleDouble.databaseValue) == nil)
        #elseif arch(x86_64) || arch(arm64)
            // 64 bits UInt
            XCTAssertEqual(UInt.fromDatabaseValue(minUInt64ConvertibleDouble.databaseValue)!, UInt.min)
            XCTAssertTrue(UInt.fromDatabaseValue(maxUInt64NonConvertibleDouble.databaseValue) == nil)
        #else
            fatalError("Unknown architecture")
        #endif
    }

}
