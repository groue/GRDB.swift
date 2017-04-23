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
        let expression = Column("foo").collating(.nocase) == "'fooéı👨👨🏿🇫🇷🇨🇮'" && Column("baz") >= 1
        var arguments: StatementArguments? = StatementArguments()
        let sql = expression.expressionSQL(&arguments)
        XCTAssertEqual(sql, "((\"foo\" = ? COLLATE NOCASE) AND (\"baz\" >= ?))")
        let values = arguments!.values
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], "'fooéı👨👨🏿🇫🇷🇨🇮'".databaseValue)
        XCTAssertEqual(values[1], 1.databaseValue)
    }
    
    func testWithoutArguments() {
        let expression = Column("foo").collating(.nocase) == "'fooéı👨👨🏿🇫🇷🇨🇮'" && Column("baz") >= 1
        var arguments: StatementArguments? = nil
        let sql = expression.expressionSQL(&arguments)
        XCTAssertEqual(sql, "((\"foo\" = '''fooéı👨👨🏿🇫🇷🇨🇮''' COLLATE NOCASE) AND (\"baz\" >= 1))")
    }
}
