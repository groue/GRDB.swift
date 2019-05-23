import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class FoundationNSNumberTests: GRDBTestCase {
    
    func testNSNumberDatabaseValueToSwiftType() {
        // case "c":
        let number_char = NSNumber(value: Int8.min + 1)
        XCTAssertEqual(String(cString: number_char.objCType), "c")
        let dbv_char = number_char.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_char), Int64(Int8.min + 1))
        
        // case "C":
        let number_unsignedChar = NSNumber(value: UInt8.max - 1)
//        XCTAssertEqual(String(cString: number_unsignedChar.objCType), "C") // get "s" instead of "C"
        let dbv_unsignedChar = number_unsignedChar.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedChar), Int64(UInt8.max - 1))
        
        // case "s":
        let number_short = NSNumber(value: Int16.min + 1)
        XCTAssertEqual(String(cString: number_short.objCType), "s")
        let dbv_short = number_short.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_short), Int64(Int16.min + 1))
        
        // case "S":
        let number_unsignedShort = NSNumber(value: UInt16.max - 1)
//        XCTAssertEqual(String(cString: number_unsignedShort.objCType), "S") // get "i" instead of "S"
        let dbv_unsignedShort = number_unsignedShort.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedShort), Int64(UInt16.max - 1))
        
        // case "i":
        let number_int = NSNumber(value: Int32.min + 1)
        XCTAssertEqual(String(cString: number_int.objCType), "i")
        let dbv_int = number_int.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_int), Int64(Int32.min + 1))
        
        // case "I":
        let number_unsignedInt = NSNumber(value: UInt32.max - 1)
//        XCTAssertEqual(String(cString: number_unsignedInt.objCType), "I") // get "q" instead of "I"
        let dbv_unsignedInt = number_unsignedInt.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedInt), Int64(UInt32.max - 1))
        
        // case "l":
        let number_long = NSNumber(value: Int.min + 1)
//        XCTAssertEqual(String(cString: number_long.objCType), "l") // get "q" instead of "l"
        let dbv_long = number_long.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_long), Int64(Int.min + 1))
        
        // case "L":
        let number_unsignedLong = NSNumber(value: UInt(UInt32.max))
//        XCTAssertEqual(String(cString: number_unsignedLong.objCType), "L") // get "q" instead of "L"
        let dbv_unsignedLong = number_unsignedLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedLong), Int64(UInt32.max))
        // fatal error: value can not be converted to Int64 because it is greater than Int64.max
        // _ dbv_unsignedLong = NSNumber(value: UInt.max - 1).databaseValue
        
        // case "q":
        let number_longLong = NSNumber(value: Int64.min + 1)
        XCTAssertEqual(String(cString: number_longLong.objCType), "q")
        let dbv_longLong = number_longLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_longLong), Int64(Int64.min + 1))
        
        // case "Q":
        let number_unsignedLongLong = NSNumber(value: UInt64(Int64.max))
//        XCTAssertEqual(String(cString: number_unsignedLongLong.objCType), "Q") // get "q" instead of "Q"
        let dbv_unsignedLongLong = number_unsignedLongLong.databaseValue
        XCTAssertEqual(Int64.fromDatabaseValue(dbv_unsignedLongLong), Int64.max)
        // fatal error: value can not be converted to Int64 because it is greater than Int64.max
        // _ = NSNumber(value: UInt64.max - 1).databaseValue
        
        // case "f":
        let number_float = NSNumber(value: Float(3.14159))
        XCTAssertEqual(String(cString: number_float.objCType), "f")
        let dbv_float = number_float.databaseValue
        XCTAssertEqual(Float.fromDatabaseValue(dbv_float), Float(3.14159))
        
        // case "d":
        let number_double = NSNumber(value: Double(10000000.01))
        XCTAssertEqual(String(cString: number_double.objCType), "d")
        let dbv_double = number_double.databaseValue
        XCTAssertEqual(Double.fromDatabaseValue(dbv_double), Double(10000000.01))
        
        // case "B":
        let number_bool_true = NSNumber(value: true)
        XCTAssertEqual(String(cString: number_bool_true.objCType), "c")
        let dbv_bool_true = number_bool_true.databaseValue
        XCTAssertEqual(Bool.fromDatabaseValue(dbv_bool_true), true)
        
        let number_bool_false = NSNumber(value: false)
        XCTAssertEqual(String(cString: number_bool_false.objCType), "c")
        let dbv_bool_false = number_bool_false.databaseValue
        XCTAssertEqual(Bool.fromDatabaseValue(dbv_bool_false), false)
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
    
}
