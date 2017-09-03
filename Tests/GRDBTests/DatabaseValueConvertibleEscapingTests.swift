import XCTest

#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {

    func testText() {
        XCTAssertEqual("".databaseValue.sql, "''")
        XCTAssertEqual("foo".databaseValue.sql, "'foo'")
        XCTAssertEqual("\"foo\"".databaseValue.sql, "'\"foo\"'")
        XCTAssertEqual("'foo'".databaseValue.sql, "'''foo'''")
    }
    
    func testInteger() {
        XCTAssertEqual(0.databaseValue.sql, "0")
        XCTAssertEqual(Int64.min.databaseValue.sql, "-9223372036854775808")
        XCTAssertEqual(Int64.max.databaseValue.sql, "9223372036854775807")
    }
    
    func testDouble() {
        XCTAssertEqual(0.0.databaseValue.sql, "0.0")
        XCTAssertEqual(1.0.databaseValue.sql, "1.0")
        XCTAssertEqual((-1.0).databaseValue.sql, "-1.0")
        XCTAssertEqual(1.5.databaseValue.sql, "1.5")
    }
    
    func testBlob() {
        XCTAssertEqual("".data(using: .utf8)!.databaseValue.sql, "X''")
        XCTAssertEqual("foo".data(using: .utf8)!.databaseValue.sql, "X'666F6F'")
    }
}
