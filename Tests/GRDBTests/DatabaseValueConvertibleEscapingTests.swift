import XCTest

#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {

    func testText() {
        XCTAssertEqual("".databaseValue.quotedSQL(wrappedInParenthesis: false), "''")
        XCTAssertEqual("foo".databaseValue.quotedSQL(wrappedInParenthesis: false), "'foo'")
        XCTAssertEqual("\"foo\"".databaseValue.quotedSQL(wrappedInParenthesis: false), "'\"foo\"'")
        XCTAssertEqual("'foo'".databaseValue.quotedSQL(wrappedInParenthesis: false), "'''foo'''")
    }
    
    func testInteger() {
        XCTAssertEqual(0.databaseValue.quotedSQL(wrappedInParenthesis: false), "0")
        XCTAssertEqual(Int64.min.databaseValue.quotedSQL(wrappedInParenthesis: false), "-9223372036854775808")
        XCTAssertEqual(Int64.max.databaseValue.quotedSQL(wrappedInParenthesis: false), "9223372036854775807")
    }
    
    func testDouble() {
        XCTAssertEqual(0.0.databaseValue.quotedSQL(wrappedInParenthesis: false), "0.0")
        XCTAssertEqual(1.0.databaseValue.quotedSQL(wrappedInParenthesis: false), "1.0")
        XCTAssertEqual((-1.0).databaseValue.quotedSQL(wrappedInParenthesis: false), "-1.0")
        XCTAssertEqual(1.5.databaseValue.quotedSQL(wrappedInParenthesis: false), "1.5")
    }
    
    func testBlob() {
        XCTAssertEqual(Data().databaseValue.quotedSQL(wrappedInParenthesis: false), "X''")
        XCTAssertEqual("foo".data(using: .utf8)!.databaseValue.quotedSQL(wrappedInParenthesis: false), "X'666F6F'")
    }
}
