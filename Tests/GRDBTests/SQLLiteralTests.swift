import XCTest
@testable import GRDB

class SQLLiteralTests: GRDBTestCase {
    func testSQLInitializer() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query = SQL(sql: """
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
            var query = SQL(sql: "SELECT * ")
            query = query + SQL(sql: "FROM player ")
            query = query + SQL(sql: "WHERE id = ? ", arguments: [1])
            query = query + SQL(sql: "AND name = ?", arguments: ["Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testPlusEqualOperator() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQL(sql: "SELECT * ")
            query += SQL(sql: "FROM player ")
            query += SQL(sql: "WHERE id = ? ", arguments: [1])
            query += SQL(sql: "AND name = ?", arguments: ["Arthur"])
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testAppendLiteral() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQL(sql: "SELECT * ")
            query.append(literal: SQL(sql: "FROM player "))
            query.append(literal: SQL(sql: "WHERE id = ? ", arguments: [1]))
            query.append(literal: SQL(sql: "AND name = ?", arguments: ["Arthur"]))
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, """
                SELECT * FROM player WHERE id = ? AND name = ?
                """)
            XCTAssertEqual(arguments, [1, "Arthur"])
        }
    }
    
    func testAppendRawSQL() throws {
        try makeDatabaseQueue().inDatabase { db in
            var query = SQL(sql: "SELECT * ")
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
            let sequence = AnySequence<SQL> {
                return AnyIterator {
                    guard i < 3 else { return nil }
                    i += 1
                    return SQL(sql: "(\(i) = ?)", arguments: [i])
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
                SQL(sql: "SELECT * "),
                SQL(sql: "FROM player "),
                SQL(sql: "WHERE score > ? ", arguments: [1000]),
                SQL(sql: "AND name = :name", arguments: ["name": "Arthur"]),
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
                // Test of SQL.init(_:) documentation (plus qualification)
                let columnLiteral = SQL(Column("name"))
                let suffixLiteral = SQL("O'Brien".databaseValue)
                let literal = [columnLiteral, suffixLiteral].joined(separator: " || ")
                let request = Player.aliased(TableAlias(name: "p")).select(literal)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' FROM "player" "p"
                    """)
            }
            
            do {
                // Test qualification of interpolated literal
                let literal: SQL = "\(Column("name")) || 'foo'"
                let request = Player.aliased(TableAlias(name: "p")).select(literal)
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
            let query = SQL("""
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
            let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
                let query: SQL = """
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
            let query: SQL = """
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
                let query: SQL = "SELECT \(value)"
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
            let query: SQL = "SELECT \(data)"
            
            let (sql, arguments) = try query.build(db)
            XCTAssertEqual(sql, "SELECT ?")
            XCTAssertEqual(arguments, [data])
        }
    }
    
    func testAliasedExpressionInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let query: SQL = """
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
            let query: SQL = """
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
            let query: SQL = """
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
            let query: SQL = """
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
            let query: SQL = """
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
            let condition: SQL = "name = \("Arthur")"
            let query: SQL = """
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
    
    func testSQLLiteralInterpolation2() throws {
        // Since SQL conforms to SQLExpressible, make sure it is NOT
        // interpreted as an expression when embedded in another literal.
        let literal: SQL = "\("foo") \(SQL("bar \("baz".dropFirst())"))"
        XCTAssertEqual(literal.elements.count, 4)
        switch literal.elements[0] { case .expression:      break; default: XCTFail("Expected expression") }
        switch literal.elements[1] { case .sql(" ", []):    break; default: XCTFail("Expected sql") }
        switch literal.elements[2] { case .sql("bar ", []): break; default: XCTFail("Expected sql") }
        switch literal.elements[3] { case .expression:      break; default: XCTFail("Expected expression") }
        
        let (sql, arguments) = try makeDatabaseQueue().read(literal.build)
        XCTAssertEqual(sql, "? bar ?")
        XCTAssertEqual(arguments, ["foo", "az"])
    }
    
    func testSQLRequestInterpolation() throws {
        try makeDatabaseQueue().inDatabase { db in
            let subquery: SQLRequest<Int> = "SELECT MAX(score) - \(10) FROM player"
            let query: SQL = """
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
            let query: SQL = """
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
            let query: SQL = """
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
            var query: SQL = "SELECT \(AllColumns()) "
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
            var query: SQL = "SELECT \(AllColumns()) "
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
            var query: SQL = "SELECT \(AllColumns()) "
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
            var query: SQL = "SELECT \(AllColumns()) "
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
                let alteredNameLiteral = SQL("\(nameColumn) || \("O'Brien")")
                let request = baseRequest.select(literal: alteredNameLiteral)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' FROM "player" "p"
                    """)
            }
            
            do {
                let alteredNameLiteral = SQL("\(nameColumn) || \("O'Brien")")
                let alteredNameColumn = alteredNameLiteral.forKey("alteredName")
                let request = baseRequest.select(alteredNameColumn)
                try assertEqualSQL(db, request, """
                    SELECT "p"."name" || 'O''Brien' AS "alteredName" FROM "player" "p"
                    """)
            }
            
            do {
                let subquery: SQLRequest<String> = "SELECT MAX(\(nameColumn)) FROM \(Player.self)"
                let conditionLiteral = SQL("\(nameColumn) = (\(subquery))")
                let request = baseRequest.filter(literal: conditionLiteral)
                try assertEqualSQL(db, request, """
                    SELECT "p".* FROM "player" "p" WHERE "p"."name" = (SELECT MAX("name") FROM "player")
                    """)
            }
            
            do {
                // Test of documentation
                let date = "2020-01-23"
                let createdAt = Column("createdAt")
                let creationDate = SQL("DATE(\(createdAt))")
                let request = Player.filter(creationDate == date)
                try assertEqualSQL(db, request, """
                    SELECT * FROM "player" WHERE (DATE("createdAt")) = '2020-01-23'
                    """)
            }
            
            do {
                // Here we test that users can define functions that return
                // literal expressions.
                func date(_ value: SQLExpressible) -> SQLExpression {
                    SQL("DATE(\(value))").sqlExpression
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
                    SQL("DATE(\(value.sqlExpression))").sqlExpression
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
                let query: SQL = "SELECT * FROM player ORDER BY email COLLATION \(.nocase)"
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT * FROM player ORDER BY email COLLATION NOCASE
                    """)
                XCTAssertEqual(arguments, [])
            }
            do {
                // DatabaseCollation
                let query: SQL = "SELECT * FROM player ORDER BY name COLLATION \(.localizedCompare)"
                let (sql, arguments) = try query.build(db)
                XCTAssertEqual(sql, """
                    SELECT * FROM player ORDER BY name COLLATION swiftLocalizedCompare
                    """)
                XCTAssertEqual(arguments, [])
            }
        }
    }
    
    func testIsEmpty() {
        XCTAssertTrue(SQL(elements: []).isEmpty)
        XCTAssertTrue(SQL(sql: "").isEmpty)
        XCTAssertTrue(SQL("").isEmpty)
    }
    
    func testProtocolResolution() throws {
        // SQL can feed ordering, selection, and expressions.
        acceptOrderingTerm(SQL(""))
        acceptSelectable(SQL(""))
        acceptSpecificExpressible(SQL(""))
        acceptExpressible(SQL(""))
        
        // SQL can build complex expressions and orderings
        _ = SQL("") + 1
        _ = SQL("").desc
        
        // Swift String literals are interpreted as String, even when SQL
        // is an accepted type.
        //
        // should not compile: XCTAssertEqual(acceptOrderingTerm(""), String(describing: String.self))
        // should not compile: XCTAssertEqual(acceptSelectable(""), String(describing: String.self))
        // should not compile: XCTAssertEqual(acceptSpecificExpressible(""), String(describing: String.self))
        XCTAssertEqual(acceptExpressible(""), String(describing: String.self))
        
        // When a literal can be interpreted as an ordering, a selection, or an
        // expression, then the expression interpretation is favored.
        // This test targets TableAlias subscript.
        //
        // should not compile: XCTAssertEqual(overloaded(""), "a")
        XCTAssertEqual(overloaded(SQL("")), "SQLSpecificExpressible")
        
        // In practice:
        try makeDatabaseQueue().write { db in
            struct Player: TableRecord { }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name")
                t.column("score")
            }
            let statement = try Player
                .select(SQL("id"), SQL("score").forKey("theScore"))
                .filter(SQL("name = \("O'Brien")") && SQL("score > 1000"))
                .order(SQL("score ASC"), SQL("name").desc)
                .makePreparedRequest(db)
                .statement
            XCTAssertEqual(statement.sql, """
                SELECT id, score AS "theScore" \
                FROM "player" \
                WHERE (name = ?) AND (score > 1000) ORDER BY score ASC, name DESC
                """)
            XCTAssertEqual(statement.arguments, ["O'Brien"])
        }
    }
}

// Support for testProtocolResolution()
@discardableResult
private func acceptOrderingTerm(_ x: SQLOrderingTerm) -> String {
    String(describing: type(of: x))
}

@discardableResult
private func acceptSelectable(_ x: SQLSelectable) -> String {
    String(describing: type(of: x))
}

@discardableResult
private func acceptSpecificExpressible(_ x: SQLSpecificExpressible) -> String {
    String(describing: type(of: x))
}

@discardableResult
private func acceptExpressible(_ x: SQLExpressible) -> String {
    String(describing: type(of: x))
}

private func overloaded(_ x: SQLOrderingTerm) -> String {
    "SQLOrderingTerm"
}

private func overloaded(_ x: SQLSelectable) -> String {
    "SQLSelectable"
}

private func overloaded(_ x: SQLSpecificExpressible & SQLSelectable & SQLOrderingTerm) -> String {
    "SQLSpecificExpressible"
}
