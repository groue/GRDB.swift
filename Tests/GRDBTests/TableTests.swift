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
    
    func test_fetchCount() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            let t = Table("player")
            try XCTAssertEqual(t.fetchCount(db), 0)
            try db.execute(sql: "INSERT INTO player VALUES (1, 'Alice')")
            try XCTAssertEqual(t.fetchCount(db), 1)
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
    
    func test_association_belongsTo_Table() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            let player = Table("player")
            let association = player.belongsTo(Table("team"))
            try assertEqualSQL(db, player.including(optional: association), """
                SELECT "player".*, "team".* \
                FROM "player" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.including(required: association), """
                SELECT "player".*, "team".* \
                FROM "player" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.joining(optional: association), """
                SELECT "player".* \
                FROM "player" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.joining(required: association), """
                SELECT "player".* \
                FROM "player" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
        }
    }
    
    func test_association_belongsTo_TableRecord() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            struct Team: TableRecord { }
            let player = Table("player")
            let association = player.belongsTo(Team.self)
            try assertEqualSQL(db, player.including(optional: association), """
                SELECT "player".*, "team".* \
                FROM "player" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.including(required: association), """
                SELECT "player".*, "team".* \
                FROM "player" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.joining(optional: association), """
                SELECT "player".* \
                FROM "player" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, player.joining(required: association), """
                SELECT "player".* \
                FROM "player" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
        }
    }
    
    func test_association_hasOne_Table() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            let team = Table("team")
            let association = team.hasOne(Table("player"))
            try assertEqualSQL(db, team.including(optional: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.including(required: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(optional: association), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(required: association), """
                SELECT "team".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
        }
    }
    
    func test_association_hasOne_TableRecord() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            struct Player: TableRecord { }
            let team = Table("team")
            let association = team.hasOne(Player.self)
            try assertEqualSQL(db, team.including(optional: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.including(required: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(optional: association), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(required: association), """
                SELECT "team".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
        }
    }
    
    func test_association_hasMany_Table() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            let team = Table("team")
            let association = team.hasMany(Table("player"))
            try assertEqualSQL(db, team.including(optional: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.including(required: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(optional: association), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(required: association), """
                SELECT "team".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            _ = team.including(all: association) // TODO: test
        }
    }
    
    func test_association_hasMany_TableRecord() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            struct Player: TableRecord { }
            let team = Table("team")
            let association = team.hasMany(Player.self)
            try assertEqualSQL(db, team.including(optional: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.including(required: association), """
                SELECT "team".*, "player".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(optional: association), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            try assertEqualSQL(db, team.joining(required: association), """
                SELECT "team".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id"
                """)
            _ = team.including(all: association) // TODO: test
        }
    }
    
    func test_association_to_CommonTableExpression() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            let player = Table("player")
            let cte = CommonTableExpression(named: "teamBis", request: Table("team").all())
            let association = player.association(to: cte, on: { $0["teamID"] == $1["id"] })
            try assertEqualSQL(db, player.with(cte).including(optional: association), """
                WITH "teamBis" AS (SELECT * FROM "team") \
                SELECT "player".*, "teamBis".* \
                FROM "player" \
                LEFT JOIN "teamBis" ON "player"."teamID" = "teamBis"."id"
                """)
            try assertEqualSQL(db, player.with(cte).including(required: association), """
                WITH "teamBis" AS (SELECT * FROM "team") \
                SELECT "player".*, "teamBis".* \
                FROM "player" \
                JOIN "teamBis" ON "player"."teamID" = "teamBis"."id"
                """)
            try assertEqualSQL(db, player.with(cte).joining(optional: association), """
                WITH "teamBis" AS (SELECT * FROM "team") \
                SELECT "player".* \
                FROM "player" \
                LEFT JOIN "teamBis" ON "player"."teamID" = "teamBis"."id"
                """)
            try assertEqualSQL(db, player.with(cte).joining(required: association), """
                WITH "teamBis" AS (SELECT * FROM "team") \
                SELECT "player".* \
                FROM "player" \
                JOIN "teamBis" ON "player"."teamID" = "teamBis"."id"
                """)
        }
    }
    
    func test_association_hasOneThrough() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            try db.create(table: "award") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("playerID", .integer).references("player")
            }
            
            let team = Table("team")
            let player = Table("player")
            let award = Table("award")
            let association = award.hasOne(
                Row.self,
                through: award.belongsTo(player),
                using: player.belongsTo(team))
            try assertEqualSQL(db, award.including(optional: association), """
                SELECT "award".*, "team".* \
                FROM "award" \
                LEFT JOIN "player" ON "player"."id" = "award"."playerID" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, award.including(required: association), """
                SELECT "award".*, "team".* \
                FROM "award" \
                JOIN "player" ON "player"."id" = "award"."playerID" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, award.joining(optional: association), """
                SELECT "award".* \
                FROM "award" \
                LEFT JOIN "player" ON "player"."id" = "award"."playerID" \
                LEFT JOIN "team" ON "team"."id" = "player"."teamID"
                """)
            try assertEqualSQL(db, award.joining(required: association), """
                SELECT "award".* \
                FROM "award" \
                JOIN "player" ON "player"."id" = "award"."playerID" \
                JOIN "team" ON "team"."id" = "player"."teamID"
                """)
        }
    }
    
    func test_association_hasManyThrough() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            try db.create(table: "award") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("playerID", .integer).references("player")
            }
            
            let team = Table("team")
            let player = Table("player")
            let award = Table("award")
            let association = team.hasMany(
                Row.self,
                through: team.hasMany(player),
                using: player.hasMany(award))
            try assertEqualSQL(db, team.including(optional: association), """
                SELECT "team".*, "award".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id" \
                LEFT JOIN "award" ON "award"."playerID" = "player"."id"
                """)
            try assertEqualSQL(db, team.including(required: association), """
                SELECT "team".*, "award".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id" \
                JOIN "award" ON "award"."playerID" = "player"."id"
                """)
            try assertEqualSQL(db, team.joining(optional: association), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id" \
                LEFT JOIN "award" ON "award"."playerID" = "player"."id"
                """)
            try assertEqualSQL(db, team.joining(required: association), """
                SELECT "team".* \
                FROM "team" \
                JOIN "player" ON "player"."teamID" = "team"."id" \
                JOIN "award" ON "award"."playerID" = "player"."id"
                """)
            _ = team.including(all: association) // TODO: test
        }
    }
    
    func test_association_aggregates() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamID", .integer).references("team")
            }
            
            let team = Table("team")
            let association = team.hasMany(Table("player"))
            try assertEqualSQL(db, team.annotated(with: association.count, association.max(Column("id"))), """
                SELECT "team".*, COUNT(DISTINCT "player"."id") AS "playerCount", MAX("player"."id") AS "maxPlayerId" \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id" \
                GROUP BY "team"."id"
                """)
            try assertEqualSQL(db, team.annotated(with: [association.count, association.max(Column("id"))]), """
                SELECT "team".*, COUNT(DISTINCT "player"."id") AS "playerCount", MAX("player"."id") AS "maxPlayerId" \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id" \
                GROUP BY "team"."id"
                """)
            try assertEqualSQL(db, team.having(association.isEmpty), """
                SELECT "team".* \
                FROM "team" \
                LEFT JOIN "player" ON "player"."teamID" = "team"."id" \
                GROUP BY "team"."id" \
                HAVING COUNT(DISTINCT "player"."id") = 0
                """)
        }
    }
    
    func test_delete() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("a").unique()
                t.column("b")
                t.column("c")
                t.uniqueKey(["b", "c"])
            }
            try db.create(table: "country") { t in
                t.column("code", .text).notNull().primaryKey()
            }
            try db.create(table: "document") { t in
                t.column("a")
            }

            // Use Table<Void> when we want to make sure the generic type is not used.
            
            do {
                try Table<Void>("player").deleteAll(db)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player"
                    """)
                
                try Table<Void>("player").all().deleteAll(db)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player"
                    """)
            }
            
            do {
                try Table<Void>("player").deleteOne(db, key: 1)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" = 1
                    """)
                
                try Table<Void>("country").deleteOne(db, key: "FR")
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" = 'FR'
                    """)
                
                try Table<Void>("document").deleteOne(db, key: 1)
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "document" WHERE "rowid" = 1
                    """)
            }
            
            do {
                try Table<Void>("player").deleteOne(db, key: ["a": "foo"])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE "a" = 'foo'
                    """)
                
                try Table<Void>("player").deleteOne(db, key: ["b": "bar", "c": "baz"])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE ("b" = 'bar') AND ("c" = 'baz')
                    """)
            }

            do {
                try Table<Void>("player").deleteAll(db, keys: [1, 2])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (1, 2)
                    """)
                
                try Table<Void>("country").deleteAll(db, keys: ["FR", "DE"])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" IN ('FR', 'DE')
                    """)
                
                try Table<Void>("document").deleteAll(db, keys: [1, 2])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "document" WHERE "rowid" IN (1, 2)
                    """)
            }
            
            do {
                try Table<Void>("player").deleteAll(db, keys: [["a": "toto"], ["a": "titi"]])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE ("a" = 'toto') OR ("a" = 'titi')
                    """)
                
                try Table<Void>("player").deleteAll(db, keys: [["b": "toto", "c": "titi"], ["b": "tata", "c": "tonton"]])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "player" WHERE (("b" = 'toto') AND ("c" = 'titi')) OR (("b" = 'tata') AND ("c" = 'tonton'))
                    """)
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                // Non-optional ID
                struct Country: Identifiable { var id: String }
                
                try Table<Country>("country").deleteOne(db, id: "FR")
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" = 'FR'
                    """)
                
                try Table<Country>("country").deleteAll(db, ids: ["FR", "DE"])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" IN ('FR', 'DE')
                    """)
            }
            
            if #available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6, *) {
                // Optional ID
                struct Country: Identifiable { var id: String? }
                
                try Table<Country>("country").deleteOne(db, id: "FR")
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" = 'FR'
                    """)
                
                try Table<Country>("country").deleteAll(db, ids: ["FR", "DE"])
                XCTAssertEqual(lastSQLQuery, """
                    DELETE FROM "country" WHERE "code" IN ('FR', 'DE')
                    """)
            }
        }
    }
    
    func test_updateAll() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            let assignment = Column("score").set(to: 0)
            
            // Use Table<Void> when we want to make sure the generic type is not used.
            
            do {
                try Table<Void>("player").updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0
                    """)
            }
            do {
                try Table<Void>("player").updateAll(db, [assignment])
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0
                    """)
            }
            do {
                try Table<Void>("player").updateAll(db, onConflict: .ignore, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE OR IGNORE "player" SET "score" = 0
                    """)
            }
        }
    }
}
