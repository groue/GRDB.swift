#if swift(>=5.0)
import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SQLInterpolationTests: GRDBTestCase {
    func testSQLInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 2)
        
        sql.appendInterpolation(sql: "\(1)"); sql.appendLiteral("\n")
        sql.appendInterpolation(sql: ":name", arguments: ["name": "Arthur"])

        XCTAssertEqual(sql.sql, """
            1
            :name
            """)
        XCTAssert(sql.arguments.values.isEmpty)
        XCTAssertEqual(sql.arguments.namedValues, ["name": "Arthur".databaseValue])
    }
    
    func testSelectableInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 2)
        
        // Non-existential
        sql.appendInterpolation(AllColumns()); sql.appendLiteral("\n")
        // Existential
        sql.appendInterpolation(AllColumns() as SQLSelectable)
        
        XCTAssertEqual(sql.sql, """
            *
            *
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testTableInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        struct Player: TableRecord { }
        sql.appendInterpolation(Player.self)
        
        XCTAssertEqual(sql.sql, """
            "player"
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testExpressibleInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 7)
        
        let a = Column("a")
        let b = Column("b")
        let integer: Int = 1
        let optionalInteger: Int? = 2
        let nilInteger: Int? = nil
        sql.appendInterpolation(a); sql.appendLiteral("\n")
        sql.appendInterpolation(a + 1); sql.appendLiteral("\n")
        sql.appendInterpolation(a < b); sql.appendLiteral("\n")
        sql.appendInterpolation(integer); sql.appendLiteral("\n")
        sql.appendInterpolation(optionalInteger); sql.appendLiteral("\n")
        sql.appendInterpolation(nilInteger); sql.appendLiteral("\n")
        sql.appendInterpolation(a == nilInteger)
        
        XCTAssertEqual(sql.sql, """
            "a"
            ("a" + ?)
            ("a" < "b")
            ?
            ?
            NULL
            ("a" IS NULL)
            """)
        XCTAssertEqual(sql.arguments.values, [1.databaseValue, 1.databaseValue, 2.databaseValue])
        XCTAssert(sql.arguments.namedValues.isEmpty)
    }
    
    func testQualifiedExpressionInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        sql.appendInterpolation(Column("name").aliased("foo")); sql.appendLiteral("\n")
        sql.appendInterpolation(1.databaseValue.aliased("bar"))
        
        XCTAssertEqual(sql.sql, """
            "name" AS "foo"
            ? AS "bar"
            """)
        XCTAssertEqual(sql.arguments.values, [1.databaseValue])
        XCTAssert(sql.arguments.namedValues.isEmpty)
    }
    
    func testCodingKeyInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        enum CodingKeys: String, CodingKey {
            case name
        }
        sql.appendInterpolation(CodingKeys.name)
        
        XCTAssertEqual(sql.sql, """
            "name"
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testCodingKeyColumnInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        enum CodingKeys: String, CodingKey, ColumnExpression {
            case name
        }
        sql.appendInterpolation(CodingKeys.name)
        
        XCTAssertEqual(sql.sql, """
            "name"
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testExpressibleSequenceInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 3)
        
        let set: Set = [1]
        let array = ["foo", "bar", "baz"]
        let expressions = [Column("a"), Column("b") + 2]
        sql.appendInterpolation(set); sql.appendLiteral("\n")
        sql.appendInterpolation(array); sql.appendLiteral("\n")
        sql.appendInterpolation(expressions)

        XCTAssertEqual(sql.sql, """
            (?)
            (?,?,?)
            ("a",("b" + ?))
            """)
        XCTAssertEqual(sql.arguments.values, [1.databaseValue, "foo".databaseValue, "bar".databaseValue, "baz".databaseValue, 2.databaseValue])
        XCTAssert(sql.arguments.namedValues.isEmpty)
    }
    
    func testOrderingTermInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        sql.appendInterpolation(Column("name").desc)
        
        XCTAssertEqual(sql.sql, """
            "name" DESC
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testSQLStringInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 3)
        
        sql.appendInterpolation(1)
        sql.appendInterpolation(SQLString(" + \(2) + "))
        sql.appendInterpolation(3)
        
        XCTAssertEqual(sql.sql, "? + ? + ?")
        XCTAssertEqual(sql.arguments.values, [1.databaseValue, 2.databaseValue, 3.databaseValue])
        XCTAssert(sql.arguments.namedValues.isEmpty)
    }
}
#endif

