import XCTest
@testable import GRDB

typealias DatabaseFunction = (context: COpaquePointer, argc: Int32, argv: UnsafeMutablePointer<COpaquePointer>) -> Void
private let SQLITE_TRANSIENT = unsafeBitCast(COpaquePointer(bitPattern: -1), sqlite3_destructor_type.self)

class CustomFunctionTests: GRDBTestCase {
    func testExample() {
        assertNoError {
            dbQueue.inDatabase { db in
                db.registerFunction("toto") { "toto" }
                db.registerFunction("succ") { (int: Int?) in
                    guard let int = int else { return nil }
                    return int + 1
                }
                db.registerFunction("sum") { (a: Int?, b: Int?) in (a ?? 0) + (b ?? 0) }
                db.registerVariadicFunction("sum") { databaseValues in
                    let ints = databaseValues.flatMap { $0.value() as Int? }
                    let sum = ints.reduce(0) { $0 + $1 }
                    return sum
                }
                print(Row.fetchOne(db, "SELECT toto()")!.databaseValues.first!)
                print(Row.fetchOne(db, "SELECT succ(1)")!.databaseValues.first!)
                print(Row.fetchOne(db, "SELECT succ(NULL)")!.databaseValues.first!)
                print(Row.fetchOne(db, "SELECT sum(1, 2)")!.databaseValues.first!)
                print(Row.fetchOne(db, "SELECT sum(1, 2, 3)")!.databaseValues.first!)
                print(Row.fetchOne(db, "SELECT sum(1, 2, 3, NULL)")!.databaseValues.first!)
            }
        }
    }
}
