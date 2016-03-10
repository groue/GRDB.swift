import XCTest
import GRDB

struct CustomValueType : DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return "CustomValueType".databaseValue
    }
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> CustomValueType? {
        guard let string = String.fromDatabaseValue(databaseValue) where string == "CustomValueType" else {
            return nil
        }
        return CustomValueType()
    }
}

class FunctionTests: GRDBTestCase {
    
    // MARK: - Return values
    
    func testFunctionReturningNull() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return nil
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(DatabaseValue.fetchOne(db, "SELECT f()") == nil)
            }
        }
    }
    
    func testFunctionReturningInt64() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return Int64(1)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testFunctionReturningDouble() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return 1e100
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testFunctionReturningString() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo"
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionReturningData() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo".dataUsingEncoding(NSUTF8StringEncoding)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(NSData.fetchOne(db, "SELECT f()")!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testFunctionReturningCustomValueType() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return CustomValueType()
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT f()") != nil)
            }
        }
    }
    
    // MARK: - Argument values
    
    func testFunctionArgumentNil() {
        assertNoError {
            let fn = DatabaseFunction("isNil", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].isNull
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Bool.fetchOne(db, "SELECT isNil(NULL)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(1)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(1.1)")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil('foo')")!)
                XCTAssertFalse(Bool.fetchOne(db, "SELECT isNil(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])!)
            }
        }
    }
    
    func testFunctionArgumentInt64() {
        assertNoError {
            let fn = DatabaseFunction("asInt64", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Int64?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Int64.fetchOne(db, "SELECT asInt64(NULL)") == nil)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT asInt64(1)")!, 1)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT asInt64(1.1)")!, 1)
                XCTAssertTrue(Int64.fetchOne(db, "SELECT asInt64('foo')") == nil)
                XCTAssertTrue(Int64.fetchOne(db, "SELECT asInt64(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)]) == nil)
            }
        }
    }
    
    func testFunctionArgumentDouble() {
        assertNoError {
            let fn = DatabaseFunction("asDouble", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as Double?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(Double.fetchOne(db, "SELECT asDouble(NULL)") == nil)
                XCTAssertEqual(Double.fetchOne(db, "SELECT asDouble(1)")!, 1.0)
                XCTAssertEqual(Double.fetchOne(db, "SELECT asDouble(1.1)")!, 1.1)
                XCTAssertTrue(Double.fetchOne(db, "SELECT asDouble('foo')") == nil)
                XCTAssertTrue(Double.fetchOne(db, "SELECT asDouble(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)]) == nil)
            }
        }
    }
    
    func testFunctionArgumentString() {
        assertNoError {
            let fn = DatabaseFunction("asString", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as String?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(String.fetchOne(db, "SELECT asString(NULL)") == nil)
                XCTAssertTrue(String.fetchOne(db, "SELECT asString(1)") == nil)
                XCTAssertTrue(String.fetchOne(db, "SELECT asString(1.1)") == nil)
                XCTAssertEqual(String.fetchOne(db, "SELECT asString('foo')")!, "foo")
                XCTAssertTrue(String.fetchOne(db, "SELECT asString(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)]) == nil)
            }
        }
    }
    
    func testFunctionArgumentBlob() {
        assertNoError {
            let fn = DatabaseFunction("asData", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as NSData?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(NSData.fetchOne(db, "SELECT asData(NULL)") == nil)
                XCTAssertTrue(NSData.fetchOne(db, "SELECT asData(1)") == nil)
                XCTAssertTrue(NSData.fetchOne(db, "SELECT asData(1.1)") == nil)
                XCTAssertTrue(NSData.fetchOne(db, "SELECT asData('foo')") == nil)
                XCTAssertEqual(NSData.fetchOne(db, "SELECT asData(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)])!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testFunctionArgumentCustomValueType() {
        assertNoError {
            let fn = DatabaseFunction("asCustomValueType", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                return databaseValues[0].value() as CustomValueType?
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType(NULL)") == nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType(1)") == nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType(1.1)") == nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType('foo')") == nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType('CustomValueType')") != nil)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT asCustomValueType(?)", arguments: ["foo".dataUsingEncoding(NSUTF8StringEncoding)]) == nil)
            }
        }
    }
    
    // MARK: - Argument count
    
    func testFunctionWithoutArgument() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return "foo"
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionOfOneArgument() {
        assertNoError {
            let fn = DatabaseFunction("unicodeUpper", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                let dbv = databaseValues[0]
                guard let string: String = dbv.value() else {
                    return nil
                }
                return string.uppercaseString
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
                XCTAssertEqual(String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Roué"])!, "ROUÉ")
                XCTAssertTrue(String.fetchOne(db, "SELECT unicodeUpper(NULL)") == nil)
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 2) { databaseValues in
                let ints: [Int] = databaseValues.flatMap { $0.value() }
                return ints.reduce(0, combine: +)
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            }
        }
    }
    
    func testVariadicFunction() {
        assertNoError {
            let fn = DatabaseFunction("f") { databaseValues in
                return databaseValues.count
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
            }
        }
    }
    
    // MARK: - Errors
    
    func testFunctionThrowingDatabaseErrorWithMessage() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(message: "custom error message")
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithCode() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(code: 123)
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                    XCTAssertEqual(error.message, "unknown error")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithMessageAndCode() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw DatabaseError(code: 123, message: "custom error message")
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 123)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingCustomError() {
        assertNoError {
            let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
            }
            dbQueue.addFunction(fn)
            try dbQueue.inDatabase { db in
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 1)
                    XCTAssertTrue(error.message!.containsString("CustomErrorDomain"))
                    XCTAssertTrue(error.message!.containsString("123"))
                    XCTAssertTrue(error.message!.containsString("custom error message"))
                }
            }
        }
    }
    
    // MARK: - Misc
    
    func testFunctionsAreClosures() {
        assertNoError {
            var x = 123
            let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                return x
            }
            dbQueue.addFunction(fn)
            dbQueue.inDatabase { db in
                x = 321
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 321)
            }
        }
    }
}
