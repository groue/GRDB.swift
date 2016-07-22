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
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let expression = SQLColumn("foo").collating("NOCASE") == "'bar'" && SQLColumn("baz") >= 1
            var arguments: StatementArguments? = StatementArguments()
            let sql = try dbQueue.inDatabase { db -> String in
                try expression.sql(db, &arguments)
            }
            XCTAssertEqual(sql, "((\"foo\" = ? COLLATE NOCASE) AND (\"baz\" >= ?))")
            let values = arguments!.values
            XCTAssertEqual(values.count, 2)
            XCTAssertEqual((values[0] as! String), "'bar'")
            XCTAssertEqual((values[1] as! Int), 1)
        }
    }
    
    func testWithoutArguments() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            let expression = SQLColumn("foo").collating("NOCASE") == "'bar'" && SQLColumn("baz") >= 1
            let sql = try dbQueue.inDatabase { db -> String in
                var arguments: StatementArguments? = nil
                return try expression.sql(db, &arguments)
            }
            XCTAssertEqual(sql, "((\"foo\" = '''bar''' COLLATE NOCASE) AND (\"baz\" >= 1))")
        }
    }
}
