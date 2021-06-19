import XCTest
import GRDB

class TableTests: GRDBTestCase {
    func test_Table_nameRoundTrip() {
        let table = Table("Player")
        XCTAssertEqual(table.tableName, "Player")
    }
    
    func test_Table_defaults_to_Row() {
        // This test passes if it compiles
        func f(_: Table<Row>) { }
        let table = Table("Player")
        f(table)
    }
    
    func test_Table_accepts_any_type() {
        // This test passes if it compiles
        struct S { }
        class C { }
        _ = Table<S>("ignored")
        _ = Table<C>("ignored")
    }
    
    func test_request_derivation() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            
            do {
                let t = Table("player")
                try assertEqualSQL(db, t.all(), """
                SELECT * FROM "player"
                """)
                try assertEqualSQL(db, t.none(), """
                SELECT * FROM "player" WHERE 0
                """)
                try assertEqualSQL(db, t.select(Column("id"), Column("name")), """
                SELECT "id", "name" FROM "player"
                """)
                try assertEqualSQL(db, t.select([Column("id"), Column("name")]), """
                SELECT "id", "name" FROM "player"
                """)
                try assertEqualSQL(db, t.select(sql: "id, ?", arguments: ["O'Brien"]), """
                SELECT id, 'O''Brien' FROM "player"
                """)
                try assertEqualSQL(db, t.select(literal: "id, \("O'Brien")"), """
                SELECT id, 'O''Brien' FROM "player"
                """)
                try XCTAssertEqual(t.select(Column("id"), as: Int64.self).fetchOne(db), 1)
                try XCTAssertEqual(t.select(Column("id")).fetchOne(db), 1)
                try XCTAssertEqual(t.select([Column("name")], as: String.self).fetchOne(db), "Alice")
                try XCTAssertEqual(t.select([Column("name")]).fetchOne(db), "Alice")
                try XCTAssertEqual(t.select(sql: "id", as: Int64.self).fetchOne(db), 1)
                try XCTAssertEqual(t.select(sql: "id").fetchOne(db), 1)
                try XCTAssertEqual(t.select(literal: "name", as: String.self).fetchOne(db), "Alice")
                try XCTAssertEqual(t.select(literal: "name").fetchOne(db), "Alice")
                try assertEqualSQL(db, t.annotated(with: Column.rowID), """
                SELECT *, "rowid" FROM "player"
                """)
                try assertEqualSQL(db, t.annotated(with: [Column.rowID]), """
                SELECT *, "rowid" FROM "player"
                """)
                try assertEqualSQL(db, t.filter(Column("id") > 10), """
                SELECT * FROM "player" WHERE "id" > 10
                """)
                try assertEqualSQL(db, t.filter(key: 1), """
                SELECT * FROM "player" WHERE "id" = 1
                """)
                try assertEqualSQL(db, t.filter(keys: [1, 2, 3]), """
                SELECT * FROM "player" WHERE "id" IN (1, 2, 3)
                """)
                try assertEqualSQL(db, t.filter(key: ["id": 1]), """
                SELECT * FROM "player" WHERE "id" = 1
                """)
                try assertEqualSQL(db, t.filter(keys: [["id": 1], ["id": 2]]), """
                SELECT * FROM "player" WHERE ("id" = 1) OR ("id" = 2)
                """)
                try assertEqualSQL(db, t.filter(sql: "name = ?", arguments: ["O'Brien"]), """
                SELECT * FROM "player" WHERE name = 'O''Brien'
                """)
                try assertEqualSQL(db, t.filter(literal: "name = \("O'Brien")"), """
                SELECT * FROM "player" WHERE name = 'O''Brien'
                """)
                try assertEqualSQL(db, t.order(Column("id"), Column("name").desc), """
                SELECT * FROM "player" ORDER BY "id", "name" DESC
                """)
                try assertEqualSQL(db, t.order([Column("id"), Column("name").desc]), """
                SELECT * FROM "player" ORDER BY "id", "name" DESC
                """)
                try assertEqualSQL(db, t.orderByPrimaryKey(), """
                SELECT * FROM "player" ORDER BY "id"
                """)
                try assertEqualSQL(db, t.order(sql: "IFNULL(name, ?)", arguments: ["O'Brien"]), """
                SELECT * FROM "player" ORDER BY IFNULL(name, 'O''Brien')
                """)
                try assertEqualSQL(db, t.order(literal: "IFNULL(name, \("O'Brien"))"), """
                SELECT * FROM "player" ORDER BY IFNULL(name, 'O''Brien')
                """)
                try assertEqualSQL(db, t.limit(1), """
                SELECT * FROM "player" LIMIT 1
                """)
                try assertEqualSQL(db, t.limit(1, offset: 3), """
                SELECT * FROM "player" LIMIT 1 OFFSET 3
                """)
                try assertEqualSQL(db, t.aliased(TableAlias(name: "p")), """
                SELECT "p".* FROM "player" "p"
                """)
                try assertEqualSQL(db, t.with(CommonTableExpression(named: "cte", literal: "SELECT \("O'Brien")")), """
                WITH "cte" AS (SELECT 'O''Brien') SELECT * FROM "player"
                """)
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                struct Player: Identifiable { var id: Int64 }
                let t = Table<Player>("player")
                
                try assertEqualSQL(db, t.filter(id: 1), """
                    SELECT * FROM "player" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, t.filter(ids: [1, 2, 3]), """
                    SELECT * FROM "player" WHERE "id" IN (1, 2, 3)
                    """)
                try XCTAssertEqual(t.selectID().fetchOne(db), 1)
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                struct Player: Identifiable { var id: Int64? }
                let t = Table<Player>("player")
                
                try assertEqualSQL(db, t.filter(id: 1), """
                    SELECT * FROM "player" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, t.filter(ids: [1, 2, 3]), """
                    SELECT * FROM "player" WHERE "id" IN (1, 2, 3)
                    """)
                try XCTAssertEqual(t.selectID().fetchOne(db), 1)
            }
        }
    }
    
    func test_fetch_FetchableRecord() throws {
        struct Player: FetchableRecord, Decodable, Hashable {
            var id: Int64
            var name: String
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            
            let t = Table<Player>("player")
            try XCTAssertEqual(t.fetchCursor(db).next(), Player(id: 1, name: "Alice"))
            try XCTAssertEqual(t.fetchAll(db), [Player(id: 1, name: "Alice")])
            try XCTAssertEqual(t.fetchSet(db), [Player(id: 1, name: "Alice")])
            try XCTAssertEqual(t.fetchOne(db), Player(id: 1, name: "Alice"))
        }
    }
    
    func test_fetch_Row() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            
            let t = Table("player")
            try XCTAssertEqual(t.fetchCursor(db).map { $0.copy() }.next(), ["id": 1, "name": "Alice"])
            try XCTAssertEqual(t.fetchAll(db), [["id": 1, "name": "Alice"]])
            try XCTAssertEqual(t.fetchSet(db), [["id": 1, "name": "Alice"]])
            try XCTAssertEqual(t.fetchOne(db), ["id": 1, "name": "Alice"])
        }
    }
    
    func test_fetch_DatabaseValueConvertible() throws {
        struct Value: DatabaseValueConvertible, Hashable {
            var rawValue: Int64
            var databaseValue: DatabaseValue { rawValue.databaseValue }
            static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Value? {
                Int64.fromDatabaseValue(dbValue).map(Value.init)
            }
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            
            let t = Table<Value>("player")
            try XCTAssertEqual(t.fetchCursor(db).next(), Value(rawValue: 1))
            try XCTAssertEqual(t.fetchAll(db), [Value(rawValue: 1)])
            try XCTAssertEqual(t.fetchSet(db), [Value(rawValue: 1)])
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
                try XCTAssertEqual(t.fetchOne(db), Value(rawValue: 1))
            }
        }
    }
    
    func test_fetch_optional_DatabaseValueConvertible() throws {
        struct Value: DatabaseValueConvertible, Hashable {
            var rawValue: String
            var databaseValue: DatabaseValue { rawValue.databaseValue }
            static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Value? {
                String.fromDatabaseValue(dbValue).map(Value.init)
            }
        }
        
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES ('Alice')")
            try db.execute(sql: "INSERT INTO player VALUES (NULL)")

            let t = Table<Value?>("player")
            try XCTAssertEqual(t.fetchCursor(db).next(), Value(rawValue: "Alice"))
            try XCTAssertEqual(t.fetchAll(db), [Value(rawValue: "Alice"), nil])
            try XCTAssertEqual(t.fetchSet(db), [Value(rawValue: "Alice"), nil])
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES ('Alice')")
                try XCTAssertEqual(t.fetchOne(db), Value(rawValue: "Alice"))
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES (NULL)")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
        }
    }
    
    func test_fetch_StatementColumnConvertible() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            
            let t = Table<Int64>("player")
            try XCTAssertEqual(t.fetchCursor(db).next(), 1)
            try XCTAssertEqual(t.fetchAll(db), [1])
            try XCTAssertEqual(t.fetchSet(db), [1])
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
                try XCTAssertEqual(t.fetchOne(db), 1)
            }
        }
    }
    
    func test_fetch_optional_StatementColumnConvertible() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.column("name", .text)
            }
            try db.execute(sql: "INSERT INTO player VALUES ('Alice')")
            try db.execute(sql: "INSERT INTO player VALUES (NULL)")

            let t = Table<String?>("player")
            try XCTAssertEqual(t.fetchCursor(db).next(), "Alice")
            try XCTAssertEqual(t.fetchAll(db), ["Alice", nil])
            try XCTAssertEqual(t.fetchSet(db), ["Alice", nil])
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES ('Alice')")
                try XCTAssertEqual(t.fetchOne(db), "Alice")
            }
            
            do {
                try db.execute(sql: "DELETE FROM player")
                try db.execute(sql: "INSERT INTO player VALUES (NULL)")
                try XCTAssertEqual(t.fetchOne(db), nil)
            }
        }
    }
}
