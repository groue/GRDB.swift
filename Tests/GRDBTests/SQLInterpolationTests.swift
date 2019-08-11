#if swift(>=5.0)
import XCTest
#if GRDBCUSTOMSQLITE
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
        XCTAssertEqual(sql.arguments, ["name": "Arthur"])
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
        sql.appendInterpolation(Player.self); sql.appendLiteral("\n")
        sql.appendInterpolation(tableOf: Player())
        
        XCTAssertEqual(sql.sql, """
            "player"
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
        sql.appendInterpolation(2 * (a + 1)); sql.appendLiteral("\n")
        sql.appendInterpolation(a < b); sql.appendLiteral("\n")
        sql.appendInterpolation(integer); sql.appendLiteral("\n")
        sql.appendInterpolation(optionalInteger); sql.appendLiteral("\n")
        sql.appendInterpolation(nilInteger); sql.appendLiteral("\n")
        sql.appendInterpolation(a == nilInteger)
        
        XCTAssertEqual(sql.sql, """
            "a"
            "a" + ?
            ? * ("a" + ?)
            "a" < "b"
            ?
            ?
            NULL
            "a" IS NULL
            """)
        XCTAssertEqual(sql.arguments, [1, 2, 1, 1, 2])
    }
    
    func testDatabaseValueConvertibleInterpolation() {
        func test<V: DatabaseValueConvertible>(value: V, isInterpolatedAs dbValue: DatabaseValue) {
            var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
            sql.appendInterpolation(value)
            XCTAssertEqual(sql.sql, "?")
            XCTAssertEqual(sql.arguments, [dbValue])
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
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        sql.appendInterpolation(data)
        XCTAssertEqual(sql.sql, "?")
        XCTAssertEqual(sql.arguments, [data])
    }
    
    func testQualifiedExpressionInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        sql.appendInterpolation(Column("name").aliased("foo")); sql.appendLiteral("\n")
        sql.appendInterpolation(1.databaseValue.aliased("bar"))
        
        XCTAssertEqual(sql.sql, """
            "name" AS "foo"
            ? AS "bar"
            """)
        XCTAssertEqual(sql.arguments, [1])
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
    
    func testExpressibleSequenceInterpolation() throws {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 3)
        
        let set: Set = [1]
        let array = ["foo", "bar", "baz"]
        let expressions = [Column("a"), Column("b") + 2]
        sql.appendInterpolation(set); sql.appendLiteral("\n")
        sql.appendInterpolation(array); sql.appendLiteral("\n")
        sql.appendInterpolation(expressions); sql.appendLiteral("\n")
        sql.appendInterpolation([])

        XCTAssertEqual(sql.sql, """
            (?)
            (?,?,?)
            ("a","b" + ?)
            (SELECT NULL WHERE NULL)
            """)
        XCTAssertEqual(sql.arguments, [1, "foo", "bar", "baz", 2])
    }
    
    func testOrderingTermInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 1)
        
        sql.appendInterpolation(Column("name").desc)
        
        XCTAssertEqual(sql.sql, """
            "name" DESC
            """)
        XCTAssert(sql.arguments.isEmpty)
    }
    
    func testSQLLiteralInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 3)
        
        sql.appendInterpolation(1)
        sql.appendInterpolation(literal: " + \(2) + ")
        sql.appendInterpolation(3)
        
        XCTAssertEqual(sql.sql, "? + ? + ?")
        XCTAssertEqual(sql.arguments, [1, 2, 3])
    }
    
    func testSQLRequestInterpolation() {
        var sql = SQLInterpolation(literalCapacity: 0, interpolationCount: 3)
        
        sql.appendInterpolation(SQLRequest<Void>(sql: "SELECT * FROM player WHERE id = ?", arguments: [42]))
        sql.appendInterpolation(SQLRequest<Void>(sql: "SELECT * FROM teams WHERE name = ?", arguments: ["Red"]))

        XCTAssertEqual(sql.sql, "(SELECT * FROM player WHERE id = ?)(SELECT * FROM teams WHERE name = ?)")
        XCTAssertEqual(sql.arguments, [42, "Red"])
    }
}
#endif
