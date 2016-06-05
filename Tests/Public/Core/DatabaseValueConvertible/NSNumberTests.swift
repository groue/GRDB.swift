import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class NSNumberTests: GRDBTestCase {
    
    func testNSNumberDatabaseValueToSwiftType() {
        // case "c":
        let number_char = NSNumber(char: Int8.min + 1)
        XCTAssertEqual(String.fromCString(number_char.objCType)!, "c")
        let dbv_char = number_char.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_char), Int64(Int8.min + 1))
        
        // case "C":
        let number_unsignedChar = NSNumber(unsignedChar: UInt8.max - 1)
//        XCTAssertEqual(String.fromCString(number_unsignedChar.objCType)!, "C") // get "s" instead of "C"
        let dbv_unsignedChar = number_unsignedChar.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedChar), Int64(UInt8.max - 1))
        
        // case "s":
        let number_short = NSNumber(short: Int16.min + 1)
        XCTAssertEqual(String.fromCString(number_short.objCType)!, "s")
        let dbv_short = number_short.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_short), Int64(Int16.min + 1))
        
        // case "S":
        let number_unsignedShort = NSNumber(unsignedShort: UInt16.max - 1)
//        XCTAssertEqual(String.fromCString(number_unsignedShort.objCType)!, "S") // get "i" instead of "S"
        let dbv_unsignedShort = number_unsignedShort.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedShort), Int64(UInt16.max - 1))
        
        // case "i":
        let number_int = NSNumber(int: Int32.min + 1)
        XCTAssertEqual(String.fromCString(number_int.objCType)!, "i")
        let dbv_int = number_int.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_int), Int64(Int32.min + 1))
        
        // case "I":
        let number_unsignedInt = NSNumber(unsignedInt: UInt32.max - 1)
//        XCTAssertEqual(String.fromCString(number_unsignedInt.objCType)!, "I") // get "q" instead of "I"
        let dbv_unsignedInt = number_unsignedInt.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedInt), Int64(UInt32.max - 1))
        
        // case "l":
        let number_long = NSNumber(long: Int.min + 1)
//        XCTAssertEqual(String.fromCString(number_long.objCType)!, "l") // get "q" instead of "l"
        let dbv_long = number_long.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_long), Int64(Int.min + 1))
        
        // case "L":
        let number_unsignedLong = NSNumber(unsignedLong: UInt(UInt32.max))
//        XCTAssertEqual(String.fromCString(number_unsignedLong.objCType)!, "L") // get "q" instead of "L"
        let dbv_unsignedLong = number_unsignedLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedLong), Int64(UInt32.max))
        // fatal error: value can not be converted to Int64 because it is greater than Int64.max
        // _ dbv_unsignedLong = NSNumber(unsignedLong: UInt.max - 1).databaseValue
        
        // case "q":
        let number_longLong = NSNumber(longLong: Int64.min + 1)
        XCTAssertEqual(String.fromCString(number_longLong.objCType)!, "q")
        let dbv_longLong = number_longLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_longLong), Int64(Int64.min + 1))
        
        // case "Q":
        let number_unsignedLongLong = NSNumber(unsignedLongLong: UInt64(Int64.max))
//        XCTAssertEqual(String.fromCString(number_unsignedLongLong.objCType)!, "Q") // get "q" instead of "Q"
        let dbv_unsignedLongLong = number_unsignedLongLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedLongLong), Int64.max)
        // fatal error: value can not be converted to Int64 because it is greater than Int64.max
        // _ = NSNumber(unsignedLongLong: UInt64.max - 1).databaseValue
        
        // case "f":
        let number_float = NSNumber(float: Float(3.14159))
        XCTAssertEqual(String.fromCString(number_float.objCType)!, "f")
        let dbv_float = number_float.databaseValue
        XCTAssertEqual(Float.fromDatabaseValue(dbv_float), Float(3.14159))
        
        // case "d":
        let number_double = NSNumber(double: Double(10000000.01))
        XCTAssertEqual(String.fromCString(number_double.objCType)!, "d")
        let dbv_double = number_double.databaseValue
        XCTAssertEqual(Double.fromDatabaseValue(dbv_double), Double(10000000.01))
        
        // case "B":
        let number_bool_true = NSNumber(bool: true)
        XCTAssertEqual(String.fromCString(number_bool_true.objCType)!, "c")
        let dbv_bool_true = number_bool_true.databaseValue
        XCTAssertEqual(Bool.fromDatabaseValue(dbv_bool_true), true)
        
        let number_bool_false = NSNumber(bool: false)
        XCTAssertEqual(String.fromCString(number_bool_false.objCType)!, "c")
        let dbv_bool_false = number_bool_false.databaseValue
        XCTAssertEqual(Bool.fromDatabaseValue(dbv_bool_false), false)
    }
    
    func testNSNumberDatabaseValueRoundTrip() {
        
        func roundTrip(value: NSNumber) -> Bool
        {
            let databaseValue = value.databaseValue
            guard let back = NSNumber.fromDatabaseValue(databaseValue) else
            {
                XCTFail("Failed to convert from DatabaseValue to NSNumber")
                return false
            }
            return back.isEqualToNumber(value)
        }
        
        XCTAssertTrue(roundTrip(NSNumber(int: Int32.min + 1)))
        XCTAssertTrue(roundTrip(NSNumber(double: Double(10000000.01))))
    }
    
    func testNSNumberFromDatabaseValueFailure() {
        let databaseValue_Null = DatabaseValue.Null
        let databaseValue_String = "foo".databaseValue
        let databaseValue_Blob = "bar".dataUsingEncoding(NSUTF8StringEncoding)!.databaseValue
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_Null))
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_String))
        XCTAssertNil(NSNumber.fromDatabaseValue(databaseValue_Blob))
    }
    
}
