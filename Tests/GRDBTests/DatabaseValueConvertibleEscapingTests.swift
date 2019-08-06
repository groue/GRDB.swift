import XCTest

#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {

    func testText() {
        XCTAssertEqual("".databaseValue.quotedSQL(), "''")
        XCTAssertEqual("foo".databaseValue.quotedSQL(), "'foo'")
        XCTAssertEqual("\"foo\"".databaseValue.quotedSQL(), "'\"foo\"'")
        XCTAssertEqual("'foo'".databaseValue.quotedSQL(), "'''foo'''")
    }
    
    func testInteger() {
        XCTAssertEqual(0.databaseValue.quotedSQL(), "0")
        XCTAssertEqual(Int64.min.databaseValue.quotedSQL(), "-9223372036854775808")
        XCTAssertEqual(Int64.max.databaseValue.quotedSQL(), "9223372036854775807")
    }
    
    func testDouble() {
        XCTAssertEqual(0.0.databaseValue.quotedSQL(), "0.0")
        XCTAssertEqual(1.0.databaseValue.quotedSQL(), "1.0")
        XCTAssertEqual((-1.0).databaseValue.quotedSQL(), "-1.0")
        XCTAssertEqual(1.5.databaseValue.quotedSQL(), "1.5")
    }
    
    func testBlob() {
        XCTAssertEqual(Data().databaseValue.quotedSQL(), "X''")
        XCTAssertEqual("foo".data(using: .utf8)!.databaseValue.quotedSQL(), "X'666F6F'")
    }
}
