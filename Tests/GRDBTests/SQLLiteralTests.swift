import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SQLLiteralTests: GRDBTestCase {
    func testSQLInitializer() {
        let sql = SQLLiteral(sql: """
            SELECT * FROM player
            WHERE id = \("?")
            """, arguments: [1])
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player
            WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }
    
    func testSQLLiteralInitializer() {
        let sql = SQLLiteral(literal: SQLLiteral(sql: """
            SELECT * FROM player
            WHERE id = ?
            """, arguments: [1]))
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player
            WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }
    
    func testPlusOperator() {
        var sql = SQLLiteral(sql: "SELECT * ")
        sql = sql + SQLLiteral(sql: "FROM player ")
        sql = sql + SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
        sql = sql + SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(sql.arguments, [1, "Arthur"])
    }
    
    func testPlusEqualOperator() {
        var sql = SQLLiteral(sql: "SELECT * ")
        sql += SQLLiteral(sql: "FROM player ")
        sql += SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
        sql += SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(sql.arguments, [1, "Arthur"])
    }
    
    func testAppendLiteral() {
        var sql = SQLLiteral(sql: "SELECT * ")
        sql.append(literal: SQLLiteral(sql: "FROM player "))
        sql.append(literal: SQLLiteral(sql: "WHERE id = ? ", arguments: [1]))
        sql.append(literal: SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"]))
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(sql.arguments, [1, "Arthur"])
    }
    
    func testAppendSQL() {
        var sql = SQLLiteral(sql: "SELECT * ")
        sql.append(sql: "FROM player ")
        sql.append(sql: "WHERE score > \(1000) ")
        sql.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE score > 1000 AND name = :name
            """)
        XCTAssertEqual(sql.arguments, ["name": "Arthur"])
    }
}

#if swift(>=5.0)
extension SQLLiteralTests {
    func testSQLInterpolation() {
        let sql: SQLLiteral = """
            SELECT *
            \(sql: "FROM player")
            \(sql: "WHERE score > \(1000)")
            \(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
            """
        XCTAssertEqual(sql.sql, """
            SELECT *
            FROM player
            WHERE score > 1000
            AND name = :name
            """)
        XCTAssertEqual(sql.arguments, ["name": "Arthur"])
    }
    
    func testSelectableInterpolation() {
        do {
            // Non-existential
            let sql: SQLLiteral = """
                SELECT \(AllColumns())
                FROM player
                """
            XCTAssertEqual(sql.sql, """
                SELECT *
                FROM player
                """)
            XCTAssert(sql.arguments.isEmpty)
        }
        do {
            // Existential
            let sql: SQLLiteral = """
                SELECT \(AllColumns() as SQLSelectable)
                FROM player
                """
            XCTAssertEqual(sql.sql, """
                SELECT *
                FROM player
                """)
            XCTAssert(sql.arguments.isEmpty)
        }
    }
    
    func testTableInterpolation() {
        struct Player: TableRecord { }
        let sql: SQLLiteral = """
            SELECT *
            FROM \(Player.self)
            """
        XCTAssertEqual(sql.sql, #"""
            SELECT *
            FROM "player"
            """#)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testExpressibleInterpolation() {
        let a = Column("a")
        let b = Column("b")
        let integer: Int = 1
        let optionalInteger: Int? = 2
        let nilInteger: Int? = nil
        let sql: SQLLiteral = """
            SELECT
              \(a),
              \(a + 1),
              \(a < b),
              \(integer),
              \(optionalInteger),
              \(nilInteger),
              \(a == nilInteger)
            """
        XCTAssertEqual(sql.sql, """
            SELECT
              "a",
              ("a" + ?),
              ("a" < "b"),
              ?,
              ?,
              NULL,
              ("a" IS NULL)
            """)
        XCTAssertEqual(sql.arguments, [1, 1, 2])
    }
    
    func testQualifiedExpressionInterpolation() {
        let sql: SQLLiteral = """
            SELECT \(Column("name").aliased("foo"))
            FROM player
            """
        XCTAssertEqual(sql.sql, """
            SELECT "name" AS "foo"
            FROM player
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testCodingKeyInterpolation() {
        enum CodingKeys: String, CodingKey {
            case name
        }
        let sql: SQLLiteral = """
            SELECT \(CodingKeys.name)
            FROM player
            """
        XCTAssertEqual(sql.sql, """
            SELECT "name"
            FROM player
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testCodingKeyColumnInterpolation() {
        enum CodingKeys: String, CodingKey, ColumnExpression {
            case name
        }
        let sql: SQLLiteral = """
            SELECT \(CodingKeys.name)
            FROM player
            """
        XCTAssertEqual(sql.sql, """
            SELECT "name"
            FROM player
            """)
        XCTAssert(sql.arguments.isEmpty)
    }

    func testExpressibleSequenceInterpolation() {
        let set: Set = [1]
        let array = ["foo", "bar", "baz"]
        let expressions = [Column("a"), Column("b") + 2]
        let sql: SQLLiteral = """
            SELECT * FROM player
            WHERE teamId IN \(set)
              AND name IN \(array)
              AND c IN \(expressions)
            """
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player
            WHERE teamId IN (?)
              AND name IN (?,?,?)
              AND c IN ("a",("b" + ?))
            """)
        XCTAssertEqual(sql.arguments, [1, "foo", "bar", "baz", 2])
    }
    
    func testOrderingTermInterpolation() {
        let sql: SQLLiteral = """
            SELECT * FROM player
            ORDER BY \(Column("name").desc)
            """
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player
            ORDER BY "name" DESC
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testSQLLiteralInterpolation() {
        let condition: SQLLiteral = "name = \("Arthur")"
        let sql: SQLLiteral = """
            SELECT *, \(true) FROM player
            WHERE \(literal: condition) AND score > \(1000)
            """
        XCTAssertEqual(sql.sql, """
            SELECT *, ? FROM player
            WHERE name = ? AND score > ?
            """)
        XCTAssertEqual(sql.arguments, [true, "Arthur", 1000])
    }

    func testSQLLiteralInitializerWithInterpolation() {
        let sql = SQLLiteral("""
            SELECT * FROM player
            WHERE id = \(1)
            """)
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player
            WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }

    func testPlusOperatorWithInterpolation() {
        var sql: SQLLiteral = "SELECT \(AllColumns()) "
        sql = sql + "FROM player "
        sql = sql + "WHERE id = \(1)"
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }

    func testPlusEqualOperatorWithInterpolation() {
        var sql: SQLLiteral = "SELECT \(AllColumns()) "
        sql += "FROM player "
        sql += "WHERE id = \(1)"
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }

    func testAppendLiteralWithInterpolation() {
        var sql: SQLLiteral = "SELECT \(AllColumns()) "
        sql.append(literal: "FROM player ")
        sql.append(literal: "WHERE id = \(1)")
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(sql.arguments, [1])
    }

    func testAppendSQLWithInterpolation() {
        var sql: SQLLiteral = "SELECT \(AllColumns()) "
        sql.append(sql: "FROM player ")
        sql.append(sql: "WHERE score > \(1000) ")
        sql.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
        XCTAssertEqual(sql.sql, """
            SELECT * FROM player WHERE score > 1000 AND name = :name
            """)
        XCTAssertEqual(sql.arguments, ["name": "Arthur"])
    }
}
#endif
