import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

class SQLLiteralTests: GRDBTestCase {
    func testSQLInitializer() {
        let query = SQLLiteral(sql: """
            SELECT * FROM player
            WHERE id = \("?")
            """, arguments: [1])
        XCTAssertEqual(query.sql, """
            SELECT * FROM player
            WHERE id = ?
            """)
        XCTAssertEqual(query.arguments, [1])
    }
    
    func testPlusOperator() {
        var query = SQLLiteral(sql: "SELECT * ")
        query = query + SQLLiteral(sql: "FROM player ")
        query = query + SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
        query = query + SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(query.arguments, [1, "Arthur"])
    }
    
    func testPlusEqualOperator() {
        var query = SQLLiteral(sql: "SELECT * ")
        query += SQLLiteral(sql: "FROM player ")
        query += SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
        query += SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(query.arguments, [1, "Arthur"])
    }
    
    func testAppendLiteral() {
        var query = SQLLiteral(sql: "SELECT * ")
        query.append(literal: SQLLiteral(sql: "FROM player "))
        query.append(literal: SQLLiteral(sql: "WHERE id = ? ", arguments: [1]))
        query.append(literal: SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"]))
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ? AND name = ?
            """)
        XCTAssertEqual(query.arguments, [1, "Arthur"])
    }
    
    func testAppendRawSQL() {
        var query = SQLLiteral(sql: "SELECT * ")
        query.append(sql: "FROM player ")
        query.append(sql: "WHERE score > \(1000) ")
        query.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE score > 1000 AND name = :name
            """)
        XCTAssertEqual(query.arguments, ["name": "Arthur"])
    }
    
    func testSequenceJoined() {
        // A sequence that can't be consumed twice
        var i = 0
        let sequence = AnySequence<SQLLiteral> {
            return AnyIterator {
                guard i < 3 else { return nil }
                i += 1
                return SQLLiteral(sql: "(\(i) = ?)", arguments: [i])
            }
        }
        do {
            i = 0
            let joined = sequence.joined()
            XCTAssertEqual(joined.sql, "(1 = ?)(2 = ?)(3 = ?)")
            XCTAssertEqual(joined.arguments, [1, 2, 3])
        }
        do {
            i = 0
            let joined = sequence.joined(separator: " AND ")
            XCTAssertEqual(joined.sql, "(1 = ?) AND (2 = ?) AND (3 = ?)")
            XCTAssertEqual(joined.arguments, [1, 2, 3])
        }
    }
    
    func testCollectionJoined() {
        let collection = AnyCollection([
            SQLLiteral(sql: "SELECT * "),
            SQLLiteral(sql: "FROM player "),
            SQLLiteral(sql: "WHERE score > ? ", arguments: [1000]),
            SQLLiteral(sql: "AND name = :name", arguments: ["name": "Arthur"]),
            ])
        do {
            let joined = collection.joined()
            XCTAssertEqual(joined.sql, """
            SELECT * FROM player WHERE score > ? AND name = :name
            """)
            XCTAssertEqual(joined.arguments, [1000] + ["name": "Arthur"])
        }
        do {
            let joined = collection.joined(separator: " ")
            XCTAssertEqual(joined.sql, """
            SELECT *  FROM player  WHERE score > ?  AND name = :name
            """)
            XCTAssertEqual(joined.arguments, [1000] + ["name": "Arthur"])
        }
    }
}

#if swift(>=5.0)
extension SQLLiteralTests {
    func testRawSQLInterpolation() {
        let query: SQLLiteral = """
            SELECT *
            \(sql: "FROM player")
            \(sql: "WHERE score > \(1000)")
            \(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
            """
        XCTAssertEqual(query.sql, """
            SELECT *
            FROM player
            WHERE score > 1000
            AND name = :name
            """)
        XCTAssertEqual(query.arguments, ["name": "Arthur"])
    }
    
    func testSelectableInterpolation() {
        do {
            // Non-existential
            let query: SQLLiteral = """
                SELECT \(AllColumns())
                FROM player
                """
            XCTAssertEqual(query.sql, """
                SELECT *
                FROM player
                """)
            XCTAssert(query.arguments.isEmpty)
        }
        do {
            // Existential
            let query: SQLLiteral = """
                SELECT \(AllColumns() as SQLSelectable)
                FROM player
                """
            XCTAssertEqual(query.sql, """
                SELECT *
                FROM player
                """)
            XCTAssert(query.arguments.isEmpty)
        }
    }
    
    func testTableInterpolation() {
        struct Player: TableRecord { }
        let query: SQLLiteral = """
            SELECT *
            FROM \(Player.self)
            """
        XCTAssertEqual(query.sql, #"""
            SELECT *
            FROM "player"
            """#)
        XCTAssert(query.arguments.isEmpty)
    }
    
    func testExpressibleInterpolation() {
        let a = Column("a")
        let b = Column("b")
        let integer: Int = 1
        let optionalInteger: Int? = 2
        let nilInteger: Int? = nil
        let query: SQLLiteral = """
            SELECT
              \(a),
              \(a + 1),
              \(a < b),
              \(integer),
              \(optionalInteger),
              \(nilInteger),
              \(a == nilInteger)
            """
        XCTAssertEqual(query.sql, """
            SELECT
              "a",
              ("a" + ?),
              ("a" < "b"),
              ?,
              ?,
              NULL,
              ("a" IS NULL)
            """)
        XCTAssertEqual(query.arguments, [1, 1, 2])
    }
    
    func testQualifiedExpressionInterpolation() {
        let query: SQLLiteral = """
            SELECT \(Column("name").aliased("foo"))
            FROM player
            """
        XCTAssertEqual(query.sql, """
            SELECT "name" AS "foo"
            FROM player
            """)
        XCTAssert(query.arguments.isEmpty)
    }
    
    func testCodingKeyInterpolation() {
        enum CodingKeys: String, CodingKey {
            case name
        }
        let query: SQLLiteral = """
            SELECT \(CodingKeys.name)
            FROM player
            """
        XCTAssertEqual(query.sql, """
            SELECT "name"
            FROM player
            """)
        XCTAssert(query.arguments.isEmpty)
    }
    
    func testCodingKeyColumnInterpolation() {
        enum CodingKeys: String, CodingKey, ColumnExpression {
            case name
        }
        let query: SQLLiteral = """
            SELECT \(CodingKeys.name)
            FROM player
            """
        XCTAssertEqual(query.sql, """
            SELECT "name"
            FROM player
            """)
        XCTAssert(query.arguments.isEmpty)
    }

    func testExpressibleSequenceInterpolation() {
        let set: Set = [1]
        let array = ["foo", "bar", "baz"]
        let expressions = [Column("a"), Column("b") + 2]
        let query: SQLLiteral = """
            SELECT * FROM player
            WHERE teamId IN \(set)
              AND name IN \(array)
              AND c IN \(expressions)
              AND d IN \([])
            """
        XCTAssertEqual(query.sql, """
            SELECT * FROM player
            WHERE teamId IN (?)
              AND name IN (?,?,?)
              AND c IN ("a",("b" + ?))
              AND d IN (SELECT NULL WHERE NULL)
            """)
        XCTAssertEqual(query.arguments, [1, "foo", "bar", "baz", 2])
    }
    
    func testOrderingTermInterpolation() {
        let query: SQLLiteral = """
            SELECT * FROM player
            ORDER BY \(Column("name").desc)
            """
        XCTAssertEqual(query.sql, """
            SELECT * FROM player
            ORDER BY "name" DESC
            """)
        XCTAssert(query.arguments.isEmpty)
    }
    
    func testSQLLiteralInterpolation() {
        let condition: SQLLiteral = "name = \("Arthur")"
        let query: SQLLiteral = """
            SELECT *, \(true) FROM player
            WHERE \(literal: condition) AND score > \(1000)
            """
        XCTAssertEqual(query.sql, """
            SELECT *, ? FROM player
            WHERE name = ? AND score > ?
            """)
        XCTAssertEqual(query.arguments, [true, "Arthur", 1000])
    }
    
    func testSQLRequestInterpolation() {
        let subQuery: SQLRequest<Int> = "SELECT MAX(score) - \(10) FROM player"
        let query: SQLLiteral = """
            SELECT * FROM player
            WHERE score = \(subQuery)
            """
        XCTAssertEqual(query.sql, """
            SELECT * FROM player
            WHERE score = (SELECT MAX(score) - ? FROM player)
            """)
        XCTAssertEqual(query.arguments, [10])
    }

    func testPlusOperatorWithInterpolation() {
        var query: SQLLiteral = "SELECT \(AllColumns()) "
        query = query + "FROM player "
        query = query + "WHERE id = \(1)"
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(query.arguments, [1])
    }

    func testPlusEqualOperatorWithInterpolation() {
        var query: SQLLiteral = "SELECT \(AllColumns()) "
        query += "FROM player "
        query += "WHERE id = \(1)"
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(query.arguments, [1])
    }

    func testAppendLiteralWithInterpolation() {
        var query: SQLLiteral = "SELECT \(AllColumns()) "
        query.append(literal: "FROM player ")
        query.append(literal: "WHERE id = \(1)")
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE id = ?
            """)
        XCTAssertEqual(query.arguments, [1])
    }

    func testAppendRawSQLWithInterpolation() {
        var query: SQLLiteral = "SELECT \(AllColumns()) "
        query.append(sql: "FROM player ")
        query.append(sql: "WHERE score > \(1000) ")
        query.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
        XCTAssertEqual(query.sql, """
            SELECT * FROM player WHERE score > 1000 AND name = :name
            """)
        XCTAssertEqual(query.arguments, ["name": "Arthur"])
    }
}
#endif
