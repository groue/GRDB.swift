import XCTest

#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SQLExpressionLiteralTests: GRDBTestCase {

    func testWithArguments() {
        let expression = Column("foo").collating(.nocase) == "'fooéı👨👨🏿🇫🇷🇨🇮'" && Column("baz") >= 1
        var context = SQLGenerationContext.sqlLiteralContext
        let sql = expression.expressionSQL(&context, wrappedInParenthesis: true)
        XCTAssertEqual(sql, "((\"foo\" = ? COLLATE NOCASE) AND (\"baz\" >= ?))")
        let values = context.arguments.values
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0], "'fooéı👨👨🏿🇫🇷🇨🇮'".databaseValue)
        XCTAssertEqual(values[1], 1.databaseValue)
    }
    
    func testWithoutArguments() {
        let expression = Column("foo").collating(.nocase) == "'fooéı👨👨🏿🇫🇷🇨🇮'" && Column("baz") >= 1
        var context = SQLGenerationContext.rawSQLContext
        let sql = expression.expressionSQL(&context, wrappedInParenthesis: true)
        XCTAssert(context.arguments.isEmpty)
        XCTAssertEqual(sql, "((\"foo\" = '''fooéı👨👨🏿🇫🇷🇨🇮''' COLLATE NOCASE) AND (\"baz\" >= 1))")
    }
}
