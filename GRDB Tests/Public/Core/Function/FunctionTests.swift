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
//    // Crash: SQLite error 1 with statement `SELECT f(1)`: wrong number of arguments to function f()
//    func testAddFunctionArity0WithBadNumberOfArguments() {
//        assertNoError {
//            dbQueue.inDatabase { db in
//                db.addFunction("f") { nil }
//                Row.fetchOne(db, "SELECT f(1)")
//            }
//        }
//    }
    
    func testAddFunctionReturningNull() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { nil }
                XCTAssertTrue(Row.fetchOne(db, "SELECT f()")!.value(atIndex: 0) == nil)
            }
        }
    }
    
    func testAddFunctionReturningInt64() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { Int64(1) }
                XCTAssertEqual(Int64.fetchOne(db, "SELECT f()")!, Int64(1))
            }
        }
    }
    
    func testAddFunctionReturningDouble() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { 1e100 }
                XCTAssertEqual(Double.fetchOne(db, "SELECT f()")!, 1e100)
            }
        }
    }
    
    func testAddFunctionReturningString() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { "foo" }
                XCTAssertEqual(String.fetchOne(db, "SELECT f()")!, "foo")
            }
        }
    }
    
    func testAddFunctionReturningData() {
        assertNoError {
            dbQueue.inDatabase { db in
                let data = "foo".dataUsingEncoding(NSUTF8StringEncoding)
                db.addFunction("f") { data }
                XCTAssertEqual(NSData.fetchOne(db, "SELECT f()")!, "foo".dataUsingEncoding(NSUTF8StringEncoding))
            }
        }
    }
    
    func testAddFunctionReturningCustomFunctionResult() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { CustomFunctionResult() }
                XCTAssertTrue(CustomFunctionResult.fetchOne(db, "SELECT f()") != nil)
            }
        }
    }
    
    func testAddFunctionOfOptionalInt() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { (i: Int?) in
                    if let i = i {
                        return i + 1
                    } else {
                        return "not an int"
                    }
                }
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 2)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1.1)")!, 2)
                XCTAssertEqual(String.fetchOne(db, "SELECT f(NULL)")!, "not an int")
                XCTAssertEqual(String.fetchOne(db, "SELECT f('foo')")!, "not an int")
            }
        }
    }
    
    func testAddFunctionOfInt() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f") { (i: Int) in
                    return i + 1
                }
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1)")!, 2)
                XCTAssertEqual(Int.fetchOne(db, "SELECT f(1.1)")!, 2)
                
                // Crash: SQLite error 1 with statement `SELECT f(NULL)`: Could not convert NULL to Int while evaluating function f()
                // Row.fetchOne(db, "SELECT f(NULL)")
                
                // Crash: SQLite error 1 with statement `SELECT f('foo')`: Could not convert "foo" to Int while evaluating function f().
                // Row.fetchOne(db, "SELECT f('foo')")
            }
        }
    }
    
    func testFunctionOfTwoArguments() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.addFunction("f", argumentCount: 2) { databaseValues in
                    let ints = databaseValues.flatMap { $0.value() as Int? }
                    let sum = ints.reduce(0) { $0 + $1 }
                    return sum
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
}
