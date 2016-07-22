import XCTest

#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {

    func testText() {
        XCTAssertEqual("".sqlLiteral, "''")
        XCTAssertEqual("foo".sqlLiteral, "'foo'")
        XCTAssertEqual("\"foo\"".sqlLiteral, "'\"foo\"'")
        XCTAssertEqual("'foo'".sqlLiteral, "'''foo'''")
    }
    
    func testInteger() {
        XCTAssertEqual(0.sqlLiteral, "0")
        XCTAssertEqual(Int64.min.sqlLiteral, "-9223372036854775808")
        XCTAssertEqual(Int64.max.sqlLiteral, "9223372036854775807")
    }
    
    func testDouble() {
        XCTAssertEqual(0.0.sqlLiteral, "0.0")
        XCTAssertEqual(1.0.sqlLiteral, "1.0")
        XCTAssertEqual((-1.0).sqlLiteral, "-1.0")
        XCTAssertEqual(1.5.sqlLiteral, "1.5")
    }
    
    func testBlob() {
        XCTAssertEqual("".dataUsingEncoding(NSUTF8StringEncoding)!.sqlLiteral, "NULL")
        XCTAssertEqual("foo".dataUsingEncoding(NSUTF8StringEncoding)!.sqlLiteral, "x'666f6f'")
    }
}
