import XCTest

#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SQLExpressionLiteralTests: GRDBTestCase {

    func testWithArguments() {
        let expression = SQLColumn("foo").collating("NOCASE") == "'fooéı👨👨🏿🇫🇷🇨🇮'" && SQLColumn("baz") >= 1
        var arguments: StatementArguments? = StatementArguments()
        let sql = expression.sql(&arguments)
        XCTAssertEqual(sql, "((\"foo\" = ? COLLATE NOCASE) AND (\"baz\" >= ?))")
        let values = arguments!.values
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual((values[0] as! String), "'fooéı👨👨🏿🇫🇷🇨🇮'")
        XCTAssertEqual((values[1] as! Int), 1)
    }
    
    func testWithoutArguments() {
        let expression = SQLColumn("foo").collating("NOCASE") == "'fooéı👨👨🏿🇫🇷🇨🇮'" && SQLColumn("baz") >= 1
        var arguments: StatementArguments? = nil
        let sql = expression.sql(&arguments)
        XCTAssertEqual(sql, "((\"foo\" = '''fooéı👨👨🏿🇫🇷🇨🇮''' COLLATE NOCASE) AND (\"baz\" >= 1))")
    }
}
