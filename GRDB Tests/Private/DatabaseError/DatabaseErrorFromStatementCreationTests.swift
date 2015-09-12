//import XCTest
//@testable import GRDB
//
//class DatabaseErrorFromStatementCreationTests: GRDBTestCase {
//    
//    func testDatabaseErrorThrownBySelectStatementContainSQL() {
//        dbQueue.inDatabase { db in
//            do {
//                let _ = try SelectStatement(database: db, sql: "SELECT * FROM blah")
//                XCTFail()
//            } catch let error as DatabaseError {
//                XCTAssertEqual(error.code, 1)
//                XCTAssertEqual(error.message!, "no such table: blah")
//                XCTAssertEqual(error.sql!, "SELECT * FROM blah")
//                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM blah`: no such table: blah")
//            } catch {
//                XCTFail("\(error)")
//            }
//        }
//    }
//    
//    func testDatabaseErrorThrownByUpdateStatementContainSQL() {
//        dbQueue.inDatabase { db in
//            do {
//                let _ = try UpdateStatement(database: db, sql: "UPDATE blah SET id = 12")
//                XCTFail()
//            } catch let error as DatabaseError {
//                XCTAssertEqual(error.code, 1)
//                XCTAssertEqual(error.message!, "no such table: blah")
//                XCTAssertEqual(error.sql!, "UPDATE blah SET id = 12")
//                XCTAssertEqual(error.description, "SQLite error 1 with statement `UPDATE blah SET id = 12`: no such table: blah")
//            } catch {
//                XCTFail("\(error)")
//            }
//        }
//    }
//}
