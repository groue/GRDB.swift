import XCTest
import GRDB

typealias DatabaseFunction = (context: COpaquePointer, argc: Int32, argv: UnsafeMutablePointer<COpaquePointer>) -> Void
private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

struct CustomFunctionResult : DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        return DatabaseValue(string: "CustomFunctionResult")
    }
    static func fromDatabaseValue(databaseValue: DatabaseValue) -> CustomFunctionResult? {
        guard let string = String.fromDatabaseValue(databaseValue) where string == "CustomFunctionResult" else {
            return nil
        }
        return CustomFunctionResult()
    }
}

class FunctionTests: GRDBTestCase {
    func testAddFunctionReturningNull() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in nil }
                XCTAssertTrue(Row.fetchOne(db, "SELECT f()")!.value(atIndex: 0) == nil)
            }
        }
    }
    
    func testAddFunctionReturningInt64() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in Int64(1) }
                XCTAssertEqual(Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testAddFunctionReturningDouble() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in 1e100 }
                XCTAssertEqual(Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testAddFunctionReturningString() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in "foo" }
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testAddFunctionReturningData() {
        assertNoError {
            dbQueue.inDatabase { db in
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                db.addFunction("f", argumentCount: 0) { databaseValues in data }
                XCTAssertEqual(NSData.fetchOne(db, "SELECT f()")!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testAddFunctionReturningCustomFunctionResult() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in CustomFunctionResult() }
                XCTAssertTrue(CustomFunctionResult.fetchOne(db, "SELECT f()") != nil)
            }
        }
    }
    
    func testFunctionWithoutArgument() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 0) { databaseValues in
                    return "foo"
                }
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testFunctionOfOneArgument() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("unicodeUpper", argumentCount: 1) { (databaseValues: [DatabaseValue]) in
                    let dbv = databaseValues.first!
                    guard let string = dbv.value() as String? else { return nil }
                    return string.uppercaseString
                }
                XCTAssertEqual(String.fetchOne(db, "SELECT upper(?)", arguments: ["Roué"])!, "ROUé")
                XCTAssertEqual(String.fetchOne(db, "SELECT unicodeUpper(?)", arguments: ["Roué"])!, "ROUÉ")
                XCTAssertTrue(String.fetchOne(db, "SELECT unicodeUpper(NULL)") == nil)
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 2) { databaseValues in
                    let ints: [Int] = databaseValues.flatMap { $0.value() }
                    return ints.reduce(0, combine: +)
                }
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 2)")!, 3)
            }
        }
    }
    
    func testVariadicFunction() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addVariadicFunction("f") { databaseValues in
                    return databaseValues.count
                }
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 0)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 1)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1, 1)")!, 2)
            }
        }
    }
    
    func testFunctionsAreClosures() {
        assertNoError {
            dbQueue.inDatabase { db in
                let x = 123
                db.addFunction("f", argumentCount: 0) { databaseValues in
                    return x
                }
                XCTAssertEqual(Int.fetchOne(db, "SELECT f()")!, 123)
            }
        }
    }

    func testFunctionThrowingDatabaseErrorWithMessage() {
        assertNoError {
            try dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 1) { databaseValues in
                    throw DatabaseError(message: "custom error message")
                }
                do {
                    try db.execute("CREATE TABLE items (value INT)")
                    try db.execute("INSERT INTO items VALUES (f(1))")
                    XCTFail("Expected DatabaseError")
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, SQLITE_ERROR)
                    XCTAssertEqual(error.message, "custom error message")
                }
            }
        }
    }
    
    func testFunctionThrowingDatabaseErrorWithCode() {
        assertNoError {
            try dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 1) { databaseValues in
                    throw DatabaseError(code: 123, message: "custom error message")
                }
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
                db.addFunction("f", argumentCount: 1) { databaseValues in
                    throw NSError(domain: "CustomErrorDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "custom error message"])
                }
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
}
