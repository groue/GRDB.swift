import XCTest
import GRDB

struct CustomValueType : DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return DatabaseValue("CustomValueType")
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return nil
                }
                db.addFunction(fn)
                XCTAssertTrue(DatabaseValue.fetchOne(db, "SELECT f()")!.isNull)
            }
        }
    }
    
    func testFunctionReturningInt64() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return Int64(1)
                }
                db.addFunction(fn)
                XCTAssertEqual(Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testFunctionReturningDouble() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return 1e100
                }
                db.addFunction(fn)
                XCTAssertEqual(Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testFunctionReturningString() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return "foo"
                }
                db.addFunction(fn)
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionReturningData() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return "foo".dataUsingEncoding(NSUTF8StringEncoding)
                }
                db.addFunction(fn)
                XCTAssertEqual(NSData.fetchOne(db, "SELECT f()")!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testFunctionReturningCustomValueType() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return CustomValueType()
                }
                db.addFunction(fn)
                XCTAssertTrue(CustomValueType.fetchOne(db, "SELECT f()") != nil)
            }
        }
    }
    
    // MARK: - Argument values
    
    func testFunctionArgumentNil() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("isNil", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].isNull
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("asInt64", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].value() as Int64?
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("asDouble", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].value() as Double?
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("asString", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].value() as String?
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("asData", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].value() as NSData?
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("asCustomValueType", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    return databaseValues[0].value() as CustomValueType?
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return "foo"
                }
                db.addFunction(fn)
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionOfOneArgument() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("unicodeUpper", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    let dbv = databaseValues[0]
                    guard let string: String = dbv.value() else {
                        return nil
                    }
                    return string.uppercaseString
                }
                db.addFunction(fn)
                XCTAssertEqual(String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
                XCTAssertEqual(String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Roué"])!, "ROUÉ")
                XCTAssertTrue(String.fetchOne(db, "SELECT unicodeUpper(NULL)") == nil)
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 2) { databaseValues in
                    let ints: [Int] = databaseValues.flatMap { $0.value() }
                    return ints.reduce(0, combine: +)
                }
                db.addFunction(fn)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            }
        }
    }
    
    func testVariadicFunction() {
        assertNoError {
            dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f") { databaseValues in
                    return databaseValues.count
                }
                db.addFunction(fn)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
            }
        }
    }
    
    // MARK: - Errors
    
    func testFunctionThrowingDatabaseErrorWithMessage() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                    throw DatabaseError(message: "custom error message")
                }
                db.addFunction(fn)
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
            try dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                    throw DatabaseError(code: 123)
                }
                db.addFunction(fn)
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
            try dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                    throw DatabaseError(code: 123, message: "custom error message")
                }
                db.addFunction(fn)
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
            try dbQueue.inDatabase { db in
                let fn = DatabaseFunction("f", argumentCount: 1) { databaseValues in
                    throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
                }
                db.addFunction(fn)
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
            dbQueue.inDatabase { db in
                let x = 123
                let fn = DatabaseFunction("f", argumentCount: 0) { databaseValues in
                    return x
                }
                db.addFunction(fn)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 123)
            }
        }
    }
}
