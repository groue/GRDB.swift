import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

private struct Player: Codable, PersistableRecord, FetchableRecord {
    var id: Int64
    var name: String
    var score: Int
    var bonus: Int
    
    static func createTable(_ db: Database) throws {
        try db.create(table: "player") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text)
            t.column("score", .integer)
            t.column("bonus", .integer)
        }
    }
}

private enum Columns: String, ColumnExpression {
    case id, name, score, bonus
}

private extension QueryInterfaceRequest where RowDecoder == Player {
    func incrementScore(_ db: Database) throws {
        try updateAll(db, Columns.score += 1)
    }
}

class MutablePersistableRecordUpdateTests: GRDBTestCase {
    func testRequestUpdateAll() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            let assignment = Columns.score <- 0
            
            try Player.updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.filter(Columns.name == "Arthur").updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE \"name\" = 'Arthur'
                """)
            
            try Player.filter(key: 1).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" = 1
                """)
            
            try Player.filter(keys: [1, 2]).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE "id" IN (1, 2)
                """)
            
            try Player.filter(sql: "id = 1").updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE id = 1
                """)
            
            try Player.filter(sql: "id = 1").filter(Columns.name == "Arthur").updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0 WHERE (id = 1) AND (\"name\" = 'Arthur')
                """)
            
            try Player.select(Columns.name).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.order(Columns.name).updateAll(db, assignment)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Player.limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1
                    """)
                
                try Player.order(Columns.name).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0
                    """)
                
                try Player.order(Columns.name).limit(1).updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" LIMIT 1
                    """)
                
                try Player.order(Columns.name).limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 ORDER BY \"name\" DESC LIMIT 1 OFFSET 2
                    """)
                
                try Player.limit(1, offset: 2).reversed().updateAll(db, assignment)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 LIMIT 1 OFFSET 2
                    """)
            }
        }
    }
    
    func testComplexAssignment() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score <- Columns.score * (Columns.bonus + 1))
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" + 1)
                """)
        }
    }
    
    func testAssignmentSubtractAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score -= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - 1
                """)
            
            try Player.updateAll(db, Columns.score -= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - "bonus"
                """)
            
            try Player.updateAll(db, Columns.score -= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score -= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" - ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentAddAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score += 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + 1
                """)
            
            try Player.updateAll(db, Columns.score += Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + "bonus"
                """)
            
            try Player.updateAll(db, Columns.score += -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score += Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" + ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentMultiplyAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score *= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * 1
                """)
            
            try Player.updateAll(db, Columns.score *= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * "bonus"
                """)
            
            try Player.updateAll(db, Columns.score *= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score *= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" * ("bonus" * 2)
                """)
        }
    }
    
    func testAssignmentDivideAndAssign() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score /= 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / 1
                """)
            
            try Player.updateAll(db, Columns.score /= Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / "bonus"
                """)
            
            try Player.updateAll(db, Columns.score /= -Columns.bonus)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / (-"bonus")
                """)
            
            try Player.updateAll(db, Columns.score /= Columns.bonus * 2)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = "score" / ("bonus" * 2)
                """)
        }
    }
    
    func testMultipleAssignments() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Columns.score <- 0, Columns.bonus <- 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.updateAll(db, [Columns.score <- 0, Columns.bonus <- 1])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.all().updateAll(db, Columns.score <- 0, Columns.bonus <- 1)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
            
            try Player.all().updateAll(db, [Columns.score <- 0, Columns.bonus <- 1])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0, "bonus" = 1
                """)
        }
    }
    
    func testUpdateAllWithoutAssignmentDoesNotAccessTheDatabase() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            sqlQueries.removeAll()
            try XCTAssertEqual(Player.updateAll(db, []), 0)
            try XCTAssertEqual(Player.all().updateAll(db, []), 0)
            XCTAssert(sqlQueries.isEmpty)
        }
    }
    
    func testUpdateAllReturnsNumberOfUpdatedRows() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 0, bonus: 2).insert(db)
            try Player(id: 2, name: "Barbara", score: 0, bonus: 1).insert(db)
            try Player(id: 3, name: "Craig", score: 0, bonus: 0).insert(db)
            try Player(id: 4, name: "Diane", score: 0, bonus: 3).insert(db)
            
            let assignment = Columns.score += 1
            
            try XCTAssertEqual(Player.updateAll(db, assignment), 4)
            try XCTAssertEqual(Player.filter(key: 1).updateAll(db, assignment), 1)
            try XCTAssertEqual(Player.filter(key: 5).updateAll(db, assignment), 0)
            try XCTAssertEqual(Player.filter(Columns.bonus > 1).updateAll(db, assignment), 2)
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try XCTAssertEqual(Player.limit(1).updateAll(db, assignment), 1)
                try XCTAssertEqual(Player.limit(2).updateAll(db, assignment), 2)
                try XCTAssertEqual(Player.limit(2, offset: 3).updateAll(db, assignment), 1)
                try XCTAssertEqual(Player.limit(10).updateAll(db, assignment), 4)
            }
        }
    }
    
    func testQueryInterfaceExtension() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            try Player(id: 1, name: "Arthur", score: 0, bonus: 0).insert(db)
            try Player(id: 2, name: "Barbara", score: 0, bonus: 0).insert(db)
            try Player(id: 3, name: "Craig", score: 0, bonus: 0).insert(db)
            try Player(id: 4, name: "Diane", score: 0, bonus: 0).insert(db)
            
            try Player.all().incrementScore(db)
            try XCTAssertEqual(Player.filter(Columns.score == 1).fetchCount(db), 4)
            
            try Player.filter(key: 1).incrementScore(db)
            try XCTAssertEqual(Player.fetchOne(db, key: 1)!.score, 2)
        }
    }
    
    func testConflictPolicyAbort() throws {
        struct AbortPlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .abort)
            func encode(to container: inout PersistenceContainer) { }
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try AbortPlayer.updateAll(db, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.updateAll(db, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.all().updateAll(db, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try AbortPlayer.all().updateAll(db, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyIgnore() throws {
        struct IgnorePlayer: PersistableRecord {
            static let databaseTableName = "player"
            static let persistenceConflictPolicy = PersistenceConflictPolicy(insert: .abort, update: .ignore)
            func encode(to container: inout PersistenceContainer) { }
        }
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try IgnorePlayer.updateAll(db, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.updateAll(db, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.all().updateAll(db, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try IgnorePlayer.all().updateAll(db, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testConflictPolicyCustom() throws {
        try makeDatabaseQueue().write { db in
            try Player.createTable(db)
            
            try Player.updateAll(db, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE "player" SET "score" = 0
                """)
            
            try Player.updateAll(db, onConflict: .ignore, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.updateAll(db, onConflict: .ignore, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.all().updateAll(db, onConflict: .ignore, Column("score") <- 0)
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
            
            try Player.all().updateAll(db, onConflict: .ignore, [Column("score") <- 0])
            XCTAssertEqual(self.lastSQLQuery, """
                UPDATE OR IGNORE "player" SET "score" = 0
                """)
        }
    }
    
    func testJoinedRequestUpdate() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord {
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("active", .boolean)
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("teamId", .integer).references("team")
                t.column("score", .integer)
            }
            
            do {
                try Player.including(required: Player.team).updateAll(db, Column("score") <- 0)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE rowid IN (\
                    SELECT "player"."rowid" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId")
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                try Player.aliased(alias).including(required: Player.team).updateAll(db, Column("score") <- 0)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE rowid IN (\
                    SELECT "p"."rowid" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId")
                    """)
            }
            do {
                try Team.having(Team.players.isEmpty).updateAll(db, Column("active") <- false)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0 WHERE rowid IN (\
                    SELECT "team"."rowid" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."rowid") = 0)
                    """)
            }
            do {
                try Team.including(all: Team.players).updateAll(db, Column("active") <- false)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "team" SET "active" = 0
                    """)
            }
        }
    }
    
    func testGroupedRequestUpdate() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.column("active", .boolean)
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                try Player.all().groupByPrimaryKey().updateAll(db, Column("score") <- 0)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE rowid IN (\
                    SELECT "rowid" \
                    FROM "player" \
                    GROUP BY "id")
                    """)
            }
            do {
                try Player.all().group(Column.rowID).updateAll(db, Column("score") <- 0)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "player" SET "score" = 0 WHERE rowid IN (\
                    SELECT "rowid" \
                    FROM "player" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().groupByPrimaryKey().updateAll(db, Column("active") <- true)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE rowid IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "countryCode", "citizenId")
                    """)
            }
            do {
                try Passport.all().group(Column.rowID).updateAll(db, Column("active") <- true)
                XCTAssertEqual(self.lastSQLQuery, """
                    UPDATE "passport" SET "active" = 1 WHERE rowid IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
        }
    }
}
