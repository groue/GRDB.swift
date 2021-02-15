import XCTest
@testable import GRDB

class SQLLiteralTests: GRDBTestCase {
    func testSQLInitializer() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query = SQLLiteral(sql: """
                SELECT * FROM player
                WHERE id = \("?")
                """, arguments: [1])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE id = ?
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testPlusOperator() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQLLiteral(sql: "SELECT * ")
            query = query + SQLLiteral(sql: "FROM player ")
            query = query + SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
            query = query + SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testPlusEqualOperator() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQLLiteral(sql: "SELECT * ")
            query += SQLLiteral(sql: "FROM player ")
            query += SQLLiteral(sql: "WHERE id = ? ", arguments: [1])
            query += SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testAppendLiteral() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQLLiteral(sql: "SELECT * ")
            query.append(literal: SQLLiteral(sql: "FROM player "))
            query.append(literal: SQLLiteral(sql: "WHERE id = ? ", arguments: [1]))
            query.append(literal: SQLLiteral(sql: "AND name = ?", arguments: ["Arthur"]))
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testAppendRawSQL() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQLLiteral(sql: "SELECT * ")
            query.append(sql: "FROM player ")
            query.append(sql: "WHERE score > \(1000) ")
            query.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE score > 1000 AND name = :name
                """)
            XCTAssertEqual(arguments, ["name": "Arthur"])
        }
    }
    
    func testSequenceJoined() throws {
        try makeDatabaseQueue().inDatabase { db in
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
                let (sql, arguments) = try joined.build(db)
                XCTAssertEqual(sql, "(1 = ?)(2 = ?)(3 = ?)")
                XCTAssertEqual(arguments, [1, 2, 3])
            }
            do {
                i = 0
                let joined = sequence.joined(separator: " AND ")
                let (sql, arguments) = try joined.build(db)
                XCTAssertEqual(sql, "(1 = ?) AND (2 = ?) AND (3 = ?)")
                XCTAssertEqual(arguments, [1, 2, 3])
            }
        }
    }
    
    func testCollectionJoined() throws {
        try makeDatabaseQueue().inDatabase { db in
            let collection = AnyCollection([
                SQLLiteral(sql: "SELECT * "),
                SQLLiteral(sql: "FROM player "),
                SQLLiteral(sql: "WHERE score > ? ", arguments: [1000]),
                SQLLiteral(sql: "AND name = :name", arguments: ["name": "Arthur"]),
            ])
            do {
                let joined = collection.joined()
                let (sql, arguments) = try joined.build(db)
                XCTAssertEqual(sql, """
                    SELECT * FROM player WHERE score > ? AND name = :name
                    """)
                XCTAssertEqual(arguments, [1000] + ["name": "Arthur"])
            }
            do {
                let joined = collection.joined(separator: " ")
                let (sql, arguments) = try joined.build(db)
                XCTAssertEqual(sql, """
                    SELECT *  FROM player  WHERE score > ?  AND name = :name
                    """)
                XCTAssertEqual(arguments, [1000] + ["name": "Arthur"])
            }
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
                // Test qualification of interpolated literal
                let literal: SQLLiteral = "\(Column("name")) || 'foo'"
                let request = Player.aliased(TableAlias(name: "p")).select(literal.sqlExpression)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'foo' FROM "player" "p"
                    """)
            }
        }
    }
}

extension SQLLiteralTests {
    func testLiteralInitializer() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query = SQLLiteral("""
                SELECT * FROM player
                WHERE id = \(1)
                """)
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE id = ?
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testRawSQLInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query: SQLLiteral = """
                SELECT *
                \(sql: "FROM player")
                \(sql: "WHERE score > \(1000)")
                \(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT *
                FROM player
                WHERE score > 1000
                AND name = :name
                """)
            XCTAssertEqual(arguments, ["name": "Arthur"])
        }
    }
    
    func testSelectableInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            do {
                // Non-existential
                let query: SQLLiteral = """
                    SELECT \(AllColumns())
                    FROM player
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT *
                    FROM player
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                // Existential
                let query: SQLLiteral = """
                    SELECT \(AllColumns() as SQLSelectable)
                    FROM player
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT *
                    FROM player
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                // Existential
                let query: SQLLiteral = """
                    SELECT \(nil as SQLSelectable?)
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT NULL
                    """)
                XCTAssert(arguments.isEmpty)
            }
        }
    }
    
    func testTableInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: TableRecord { }
            do {
                // Non-existential
                let query: SQLLiteral = """
                    SELECT *
                    FROM \(Player.self)
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT *
                    FROM "player"
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                // Non-existential
                let query: SQLLiteral = """
                    INSERT INTO \(tableOf: Player()) DEFAULT VALUES
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    INSERT INTO "player" DEFAULT VALUES
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                // Existential
                let query: SQLLiteral = """
                    INSERT INTO \(tableOf: Player() as TableRecord) DEFAULT VALUES
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    INSERT INTO "player" DEFAULT VALUES
                    """)
                XCTAssert(arguments.isEmpty)
            }
        }
    }
    
    func testTableSelectionInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: TableRecord { }
            struct AltPlayer: TableRecord {
                static let databaseSelection: [SQLSelectable] = [Column("id"), Column("name")]
            }
            do {
                let query: SQLLiteral = """
                    SELECT \(columnsOf: Player.self)
                    FROM player
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT "player".*
                    FROM player
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                let query: SQLLiteral = """
                    SELECT \(columnsOf: Player.self, tableAlias: "p")
                    FROM player p
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT "p".*
                    FROM player p
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                let query: SQLLiteral = """
                    SELECT \(columnsOf: AltPlayer.self)
                    FROM player
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT "altPlayer"."id", "altPlayer"."name"
                    FROM player
                    """)
                XCTAssert(arguments.isEmpty)
            }
            do {
                let query: SQLLiteral = """
                    SELECT \(columnsOf: AltPlayer.self, tableAlias: "p")
                    FROM player p
                    """
                
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT "p"."id", "p"."name"
                    FROM player p
                    """)
                XCTAssert(arguments.isEmpty)
            }
        }
    }
    
    func testExpressibleInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
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
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
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
            XCTAssertEqual(arguments, [1, 2, 1, 1, 2])
        }
    }
    
    func testDatabaseValueConvertibleInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            func test<V: DatabaseValueConvertible>(value: V, isInterpolatedAs dbValue: DatabaseValue) throws {
                let query: SQLLiteral = "SELECT \(value)"
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, "SELECT ?")
                XCTAssertEqual(arguments, [dbValue])
            }
            
            struct V: DatabaseValueConvertible {
                var databaseValue: DatabaseValue {
                    "V".databaseValue
                }
                
                static func fromDatabaseValue(_ dbValue: DatabaseValue) -> V? {
                    nil
                }
            }
            
            try test(value: 42, isInterpolatedAs: 42.databaseValue)
            try test(value: 1.23, isInterpolatedAs: 1.23.databaseValue)
            try test(value: "foo", isInterpolatedAs: "foo".databaseValue)
            try test(value: "foo".data(using: .utf8)!, isInterpolatedAs: "foo".data(using: .utf8)!.databaseValue)
            try test(value: V(), isInterpolatedAs: "V".databaseValue)
        }
    }
    
    func testDataInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            // This test makes sure the Sequence conformance of Data does not
            // kick in.
            let data = "SQLite".data(using: .utf8)!
            let query: SQLLiteral = "SELECT \(data)"
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, "SELECT ?")
            XCTAssertEqual(arguments, [data])
        }
    }
    
    func testAliasedExpressionInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query: SQLLiteral = """
                SELECT \(Column("name").forKey("foo")), \(1.databaseValue.forKey("bar"))
                FROM player
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT "name" AS "foo", ? AS "bar"
                FROM player
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testCodingKeyInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            enum CodingKeys: String, CodingKey {
                case name
            }
            let query: SQLLiteral = """
                SELECT \(CodingKeys.name)
                FROM player
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT "name"
                FROM player
                """)
            XCTAssert(arguments.isEmpty)
        }
    }
    
    func testCodingKeyColumnInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            enum CodingKeys: String, CodingKey, ColumnExpression {
                case name
            }
            let query: SQLLiteral = """
                SELECT \(CodingKeys.name)
                FROM player
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT "name"
                FROM player
                """)
            XCTAssert(arguments.isEmpty)
        }
    }
    
    func testExpressibleSequenceInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let set: Set = [1]
            let array = ["foo", "bar", "baz"]
            let expressions: [SQLExpressible] = [Column("a"), Column("b") + 2]
            let query: SQLLiteral = """
                SELECT * FROM player
                WHERE teamId IN \(set)
                AND name IN \(array)
                AND c IN \(expressions)
                AND d IN \([])
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE teamId IN (?)
                AND name IN (?,?,?)
                AND c IN ("a","b" + ?)
                AND d IN (SELECT NULL WHERE NULL)
                """)
            XCTAssertEqual(arguments, [1, "foo", "bar", "baz", 2])
        }
    }
    
    func testOrderingTermInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query: SQLLiteral = """
                SELECT * FROM player
                ORDER BY \(Column("name").desc)
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                ORDER BY "name" DESC
                """)
            XCTAssert(arguments.isEmpty)
        }
    }
    
    func testSQLLiteralInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let condition: SQLLiteral = "name = \("Arthur")"
            let query: SQLLiteral = """
                SELECT *, \(true) FROM player
                WHERE \(literal: condition) AND score > \(1000)
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT *, ? FROM player
                WHERE name = ? AND score > ?
                """)
            XCTAssertEqual(arguments, [true, "Arthur", 1000])
        }
    }
    
    func testSQLRequestInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let subquery: SQLRequest<Int> = "SELECT MAX(score) - \(10) FROM player"
            let query: SQLLiteral = """
                SELECT * FROM player
                WHERE score = (\(subquery))
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE score = (SELECT MAX(score) - ? FROM player)
                """)
            XCTAssertEqual(arguments, [10])
        }
    }
    
    func testQueryInterfaceRequestInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            struct Player: TableRecord { }
            let subquery = Player.select(max(Column("score")) - 10)
            let query: SQLLiteral = """
                SELECT * FROM player
                WHERE score = (\(subquery))
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE score = (SELECT MAX("score") - ? FROM "player")
                """)
            XCTAssertEqual(arguments, [10])
        }
    }
    
    func testJoinedQueryInterfaceRequestInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamId", .integer).references("team")
                t.column("score", .integer)
            }
            struct Player: TableRecord { }
            struct Team: TableRecord { }
            let subquery = Player
                .select(max(Column("score")) - 10)
                .joining(required: Player.belongsTo(Team.self))
            let query: SQLLiteral = """
                SELECT * FROM player
                WHERE score = (\(subquery))
                """
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player
                WHERE score = (SELECT MAX("player"."score") - ? FROM "player" JOIN "team" ON "team"."id" = "player"."teamId")
                """)
            XCTAssertEqual(arguments, [10])
        }
    }
    
    func testPlusOperatorWithInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query: SQLLiteral = "SELECT \(AllColumns()) "
            query = query + "FROM player "
            query = query + "WHERE id = \(1)"
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ?
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testPlusEqualOperatorWithInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query: SQLLiteral = "SELECT \(AllColumns()) "
            query += "FROM player "
            query += "WHERE id = \(1)"
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ?
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testAppendLiteralWithInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query: SQLLiteral = "SELECT \(AllColumns()) "
            query.append(literal: "FROM player ")
            query.append(literal: "WHERE id = \(1)")
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ?
                """)
            XCTAssertEqual(arguments, [1])
        }
    }
    
    func testAppendRawSQLWithInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query: SQLLiteral = "SELECT \(AllColumns()) "
            query.append(sql: "FROM player ")
            query.append(sql: "WHERE score > \(1000) ")
            query.append(sql: "AND \("name") = :name", arguments: ["name": "Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE score > 1000 AND name = :name
                """)
            XCTAssertEqual(arguments, ["name": "Arthur"])
        }
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
                let subquery: SQLRequest<String> = "SELECT MAX(\(nameColumn)) FROM \(Player.self)"
                let conditionLiteral = SQLLiteral("\(nameColumn) = (\(subquery))")
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
            
            do {
                // Here we test that users can define functions that return
                // literal expressions.
                func date(_ value: SQLExpressible) -> SQLExpression {
                    SQLLiteral("DATE(\(value))").sqlExpression
                }
                let createdAt = Column("createdAt")
                let request = Player.filter(date(createdAt) == "2020-01-23")
                try assertEqualSQL(db, request, """
                    SELECT * FROM "player" WHERE (DATE("createdAt")) = '2020-01-23'
                    """)
            }
            
            do {
                // Here we test that users can still define functions that
                // return literal expressions with the previously
                // supported technique.
                func date(_ value: SQLExpressible) -> SQLExpression {
                    SQLLiteral("DATE(\(value.sqlExpression))").sqlExpression
                }
                let createdAt = Column("createdAt")
                let request = Player.filter(date(createdAt) == "2020-01-23")
                try assertEqualSQL(db, request, """
                    SELECT * FROM "player" WHERE (DATE("createdAt")) = '2020-01-23'
                    """)
            }
        }
    }
    
    func testCollationInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            do {
                // Database.CollationName
                let query: SQLLiteral = "SELECT * FROM player ORDER BY email COLLATION \(.nocase)"
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT * FROM player ORDER BY email COLLATION NOCASE
                    """)
                XCTAssertEqual(arguments, [])
            }
            do {
                // DatabaseCollation
                let query: SQLLiteral = "SELECT * FROM player ORDER BY name COLLATION \(.localizedCompare)"
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT * FROM player ORDER BY name COLLATION swiftLocalizedCompare
                    """)
                XCTAssertEqual(arguments, [])
            }
        }
    }
    
    func testIsEmpty() {
        XCTAssertTrue(SQLLiteral(elements: []).isEmpty)
        XCTAssertTrue(SQLLiteral(sql: "").isEmpty)
        XCTAssertTrue(SQLLiteral("").isEmpty)
    }
}
