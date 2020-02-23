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
    
    func testQualifiedSQLLiteral() throws {
        struct Player: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("createdAt", .datetime)
            }
            
            do {
                // Test of SQLLiteral.init(_:) documentation (plus qualification)
                let columnLiteral = SQLLiteral(Column("name"))
                let suffixLiteral = SQLLiteral("O'Brien".databaseValue)
                let literal = [columnLiteral, suffixLiteral].joined(separator: " || ")
                let request = Player.aliased(TableAlias(name: "p")).select(literal.sqlExpression)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' FROM "player" "p"
                    """)
            }
            
            do {
                // Test mapSQL plus qualification
                let literal = SQLLiteral(Column("name")).mapSQL { sql in "\(sql) || 'foo'" }
                let request = Player.aliased(TableAlias(name: "p")).select(literal.sqlExpression)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'foo' FROM "player" "p"
                    """)
            }
        }
    }
}

#if swift(>=5.0)
extension SQLLiteralTests {
    func testLiteralInitializer() {
        let query = SQLLiteral("""
            SELECT * FROM player
            WHERE id = \(1)
            """)
        XCTAssertEqual(query.sql, """
            SELECT * FROM player
            WHERE id = ?
            """)
        XCTAssertEqual(query.arguments, [1])
    }
    
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
        do {
            let query: SQLLiteral = """
                SELECT *
                FROM \(Player.self)
                """
            XCTAssertEqual(query.sql, """
                SELECT *
                FROM "player"
                """)
                XCTAssert(query.arguments.isEmpty)
        }
        do {
            let query: SQLLiteral = """
                INSERT INTO \(tableOf: Player()) DEFAULT VALUES
                """
            XCTAssertEqual(query.sql, """
                INSERT INTO "player" DEFAULT VALUES
                """)
            XCTAssert(query.arguments.isEmpty)
        }
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
              \(2 * (a + 1)),
              \(a < b),
              \(integer),
              \(optionalInteger),
              \(nilInteger),
              \(a == nilInteger)
            """
        XCTAssertEqual(query.sql, """
            SELECT
              "a",
              "a" + ?,
              ? * ("a" + ?),
              "a" < "b",
              ?,
              ?,
              NULL,
              "a" IS NULL
            """)
        XCTAssertEqual(query.arguments, [1, 2, 1, 1, 2])
    }
    
    func testDatabaseValueConvertibleInterpolation() {
        func test<V: DatabaseValueConvertible>(value: V, isInterpolatedAs dbValue: DatabaseValue) {
            let query: SQLLiteral = "SELECT \(value)"
            XCTAssertEqual(query.sql, "SELECT ?")
            XCTAssertEqual(query.arguments, [dbValue])
        }
        
        struct V: DatabaseValueConvertible {
            var databaseValue: DatabaseValue {
                return "V".databaseValue
            }
            
            static func fromDatabaseValue(_ dbValue: DatabaseValue) -> V? {
                return nil
            }
        }
        
        test(value: 42, isInterpolatedAs: 42.databaseValue)
        test(value: 1.23, isInterpolatedAs: 1.23.databaseValue)
        test(value: "foo", isInterpolatedAs: "foo".databaseValue)
        test(value: "foo".data(using: .utf8)!, isInterpolatedAs: "foo".data(using: .utf8)!.databaseValue)
        test(value: V(), isInterpolatedAs: "V".databaseValue)
    }
    
    func testDataInterpolation() {
        // This test makes sure the Sequence conformance of Data does not
        // kick in.
        let data = "SQLite".data(using: .utf8)!
        let query: SQLLiteral = "SELECT \(data)"
        XCTAssertEqual(query.sql, "SELECT ?")
        XCTAssertEqual(query.arguments, [data])
    }
    
    func testAliasedExpressionInterpolation() {
        let query: SQLLiteral = """
            SELECT \(Column("name").forKey("foo")), \(1.databaseValue.forKey("bar"))
            FROM player
            """
        XCTAssertEqual(query.sql, """
            SELECT "name" AS "foo", ? AS "bar"
            FROM player
            """)
        XCTAssertEqual(query.arguments, [1])
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
              AND c IN ("a","b" + ?)
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
    
    func testQualifiedSQLInterpolation() throws {
        struct Player: TableRecord { }
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
                t.column("createdAt", .datetime)
            }
            let nameColumn = Column("name")
            let baseRequest = Player.aliased(TableAlias(name: "p"))
            
            do {
                let alteredNameLiteral = SQLLiteral("\(nameColumn) || \("O'Brien")")
                let request = baseRequest.select(literal: alteredNameLiteral)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' FROM "player" "p"
                    """)
            }
            
            do {
                let alteredNameLiteral = SQLLiteral("\(nameColumn) || \("O'Brien")")
                let alteredNameColumn = alteredNameLiteral.sqlExpression.forKey("alteredName")
                let request = baseRequest.select(alteredNameColumn)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' AS "alteredName" FROM "player" "p"
                    """)
            }
            
            do {
                let subQuery: SQLRequest<String> = "SELECT MAX(\(nameColumn)) FROM \(Player.self)"
                let conditionLiteral = SQLLiteral("\(nameColumn) = \(subQuery)")
                let request = baseRequest.filter(literal: conditionLiteral)
                try assertEqualSQL(db, request, """
                    SELECT "p".* FROM "player" "p" WHERE "p"."name" = (SELECT MAX("name") FROM "player")
                    """)
            }
            
            do {
                // Test of documentation
                let date = "2020-01-23"
                let createdAt = Column("createdAt")
                let creationDate = SQLLiteral("DATE(\(createdAt))").sqlExpression
                let request = Player.filter(creationDate == date)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "player" WHERE (DATE("createdAt")) = '2020-01-23'
                    """)
            }
        }
    }
}
#endif
