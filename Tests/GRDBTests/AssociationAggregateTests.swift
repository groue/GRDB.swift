import XCTest
#if GRDBCIPHER
import GRDBCipher
#elseif GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

private struct Team: Codable, FetchableRecord, PersistableRecord {
    static let players = hasMany(Player.self)
    static let awards = hasMany(Award.self)
    static let customPlayers = hasMany(Player.self, key: "custom")
    var id: Int64
    var name: String
}

private struct Player: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var teamId: Int64?
    var name: String
    var score: Int
}

private struct Award: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var teamId: Int64?
    var name: String
}

private struct TeamInfo: Decodable, FetchableRecord {
    var team: Team
    var averagePlayerScore: Double?
    var playerCount: Int?
    var maxPlayerScore: Int?
    var minPlayerScore: Int?
    var playerScoreSum: Int?
}

private struct CustomTeamInfo: Decodable, FetchableRecord {
    var team: Team
    var averageCustomScore: Double?
    var customCount: Int?
    var maxCustomScore: Int?
    var minCustomScore: Int?
    var customScoreSum: Int?
}

class AssociationAggregateTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "team") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "player") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).references("team")
                t.column("name", .text)
                t.column("score", .integer)
            }
            try db.create(table: "award") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).references("team")
                t.column("name", .text)
            }

            try Team(id: 1, name: "Reds").insert(db)
            try Player(id: 1, teamId: 1, name: "Arthur", score: 100).insert(db)
            try Player(id: 2, teamId: 1, name: "Barbara", score: 1000).insert(db)
            try Award(id: 1, teamId: 1, name: "World cup 2035").insert(db)
            try Award(id: 2, teamId: 1, name: "World cup 2038").insert(db)
            try Award(id: 3, teamId: 1, name: "European cup 2038").insert(db)
            try Team(id: 2, name: "Blues").insert(db)
            try Player(id: 3, teamId: 2, name: "Craig", score: 200).insert(db)
            try Player(id: 4, teamId: 2, name: "David", score: 500).insert(db)
            try Player(id: 5, teamId: 2, name: "Elise", score: 800).insert(db)
            try Award(id: 4, teamId: 2, name: "European cup 2036").insert(db)
            try Team(id: 3, name: "Greens").insert(db)
            try Award(id: 5, teamId: 3, name: "World cup 2037").insert(db)
        }
    }
    
    func testAggregateWithJoiningMethodAndTableAliasAndSQLSnippet() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let tableAlias = TableAlias(name: "custom")
            let request = Team
                .annotated(with: Team.players.count)
                .joining(required: Team.players.aliased(tableAlias).filter(sql: "custom.score < ?", arguments: [500]))
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, COUNT(DISTINCT "custom"."rowid") AS "playerCount" \
                FROM "team" \
                JOIN "player" "custom" ON (("custom"."teamId" = "team"."id") AND (custom.score < 500)) \
                GROUP BY "team"."id"
                """)
        }
    }
    
    func testAggregateWithGroup() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .select(Column("name"))
                .annotated(with: Team.players.count)
                .group(Column("name"))
            
            try assertEqualSQL(db, request, """
                SELECT "team"."name", COUNT(DISTINCT "player"."rowid") AS "playerCount" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."name"
                """)
        }
    }

    func testAnnotatedWithDefaultAverage() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.average(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, AVG("player"."score") AS "averagePlayerScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].averagePlayerScore, 550)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].averagePlayerScore, 500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].averagePlayerScore)
        }
    }
    
    func testAnnotatedWithDefaultCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.count)
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, COUNT(DISTINCT "player"."rowid") AS "playerCount" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].playerCount, 2)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].playerCount, 3)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertEqual(teamInfos[2].playerCount, 0)
        }
    }
    
    func testAnnotatedWithDefaultMax() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.max(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, MAX("player"."score") AS "maxPlayerScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].maxPlayerScore, 1000)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].maxPlayerScore, 800)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].maxPlayerScore)
        }
    }
    
    func testAnnotatedWithDefaultMin() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.min(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, MIN("player"."score") AS "minPlayerScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].minPlayerScore, 100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].minPlayerScore, 200)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].minPlayerScore)
        }
    }
    
    func testAnnotatedWithDefaultSum() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.sum(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, SUM("player"."score") AS "playerScoreSum" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].playerScoreSum, 1100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].playerScoreSum, 1500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].playerScoreSum)
        }
    }
    
    func testAnnotatedWithMultipleDefaultAggregates() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.average(Column("score")))
                .annotated(with: Team.players.count)
                .annotated(with: Team.players.min(Column("score")), Team.players.max(Column("score")))
                .annotated(with: Team.players.sum(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, \
                AVG("player"."score") AS "averagePlayerScore", \
                COUNT(DISTINCT "player"."rowid") AS "playerCount", \
                MIN("player"."score") AS "minPlayerScore", \
                MAX("player"."score") AS "maxPlayerScore", \
                SUM("player"."score") AS "playerScoreSum" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].averagePlayerScore, 550)
            XCTAssertEqual(teamInfos[0].playerCount, 2)
            XCTAssertEqual(teamInfos[0].maxPlayerScore, 1000)
            XCTAssertEqual(teamInfos[0].minPlayerScore, 100)
            XCTAssertEqual(teamInfos[0].playerScoreSum, 1100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].averagePlayerScore, 500)
            XCTAssertEqual(teamInfos[1].playerCount, 3)
            XCTAssertEqual(teamInfos[1].maxPlayerScore, 800)
            XCTAssertEqual(teamInfos[1].minPlayerScore, 200)
            XCTAssertEqual(teamInfos[1].playerScoreSum, 1500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].averagePlayerScore)
            XCTAssertEqual(teamInfos[2].playerCount, 0)
            XCTAssertNil(teamInfos[2].maxPlayerScore)
            XCTAssertNil(teamInfos[2].minPlayerScore)
            XCTAssertNil(teamInfos[2].playerScoreSum)
        }
    }
    
    func testAnnotatedWithCustomAverage() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.average(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, AVG("player"."score") AS "averageCustomScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].averageCustomScore, 550)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].averageCustomScore, 500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].averageCustomScore)
        }
    }
    
    func testAnnotatedWithCustomCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.count)
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, COUNT(DISTINCT "player"."rowid") AS "customCount" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].customCount, 2)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].customCount, 3)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertEqual(teamInfos[2].customCount, 0)
        }
    }
    
    func testAnnotatedWithCustomMax() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.max(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, MAX("player"."score") AS "maxCustomScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].maxCustomScore, 1000)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].maxCustomScore, 800)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].maxCustomScore)
        }
    }
    
    func testAnnotatedWithCustomMin() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.min(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, MIN("player"."score") AS "minCustomScore" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].minCustomScore, 100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].minCustomScore, 200)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].minCustomScore)
        }
    }
    
    func testAnnotatedWithCustomSum() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.sum(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, SUM("player"."score") AS "customScoreSum" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].customScoreSum, 1100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].customScoreSum, 1500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].customScoreSum)
        }
    }
    
    func testAnnotatedWithMultipleCustomAggregates() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.customPlayers.average(Column("score")))
                .annotated(with: Team.customPlayers.count)
                .annotated(with: Team.customPlayers.min(Column("score")), Team.customPlayers.max(Column("score")))
                .annotated(with: Team.customPlayers.sum(Column("score")))
                .orderByPrimaryKey()
                .asRequest(of: CustomTeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, \
                AVG("player"."score") AS "averageCustomScore", \
                COUNT(DISTINCT "player"."rowid") AS "customCount", \
                MIN("player"."score") AS "minCustomScore", \
                MAX("player"."score") AS "maxCustomScore", \
                SUM("player"."score") AS "customScoreSum" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].averageCustomScore, 550)
            XCTAssertEqual(teamInfos[0].customCount, 2)
            XCTAssertEqual(teamInfos[0].maxCustomScore, 1000)
            XCTAssertEqual(teamInfos[0].minCustomScore, 100)
            XCTAssertEqual(teamInfos[0].customScoreSum, 1100)
            
            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].averageCustomScore, 500)
            XCTAssertEqual(teamInfos[1].customCount, 3)
            XCTAssertEqual(teamInfos[1].maxCustomScore, 800)
            XCTAssertEqual(teamInfos[1].minCustomScore, 200)
            XCTAssertEqual(teamInfos[1].customScoreSum, 1500)
            
            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertNil(teamInfos[2].averageCustomScore)
            XCTAssertEqual(teamInfos[2].customCount, 0)
            XCTAssertNil(teamInfos[2].maxCustomScore)
            XCTAssertNil(teamInfos[2].minCustomScore)
            XCTAssertNil(teamInfos[2].customScoreSum)
        }
    }
    
    func testAnnotatedWithAggregateAlias() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.average(Column("score")).aliased("a1"))
                .annotated(with: Team.players.count.aliased("a2"))
                .annotated(with: Team.players.max(Column("score")).aliased("a3"))
                .annotated(with: Team.players.min(Column("score")).aliased("a4"))
                .annotated(with: Team.players.sum(Column("score")).aliased("a5"))
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, \
                AVG("player"."score") AS "a1", \
                COUNT(DISTINCT "player"."rowid") AS "a2", \
                MAX("player"."score") AS "a3", \
                MIN("player"."score") AS "a4", \
                SUM("player"."score") AS "a5" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id"
                """)
        }
    }
    
    func testAnnotatedWithAggregateExpression() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.average(Column("score") * Column("score")).aliased("a1"))
                .annotated(with: Team.players.max(Column("score") * 10).aliased("a3"))
                .annotated(with: Team.players.min(-Column("score")).aliased("a4"))
                .annotated(with: Team.players.sum(Column("score") * Column("score")).aliased("a5"))
            try assertEqualSQL(db, request, """
                SELECT "team".*, \
                AVG(("player"."score" * "player"."score")) AS "a1", \
                MAX(("player"."score" * 10)) AS "a3", \
                MIN(-"player"."score") AS "a4", \
                SUM(("player"."score" * "player"."score")) AS "a5" \
                FROM "team" \
                LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                GROUP BY "team"."id"
                """)
        }
    }
    
    func testAnnotatedWithMultipleCount() throws {
        struct TeamInfo: Decodable, FetchableRecord {
            var team: Team
            var lowPlayerCount: Int
            var highPlayerCount: Int
        }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request = Team
                .annotated(with: Team.players.filter(Column("score") < 500).forKey("lowPlayer").count)
                .annotated(with: Team.players.filter(Column("score") >= 500).forKey("highPlayer").count)
                .orderByPrimaryKey()
                .asRequest(of: TeamInfo.self)
            
            try assertEqualSQL(db, request, """
                SELECT "team".*, \
                COUNT(DISTINCT "player1"."rowid") AS "lowPlayerCount", \
                COUNT(DISTINCT "player2"."rowid") AS "highPlayerCount" \
                FROM "team" \
                LEFT JOIN "player" "player1" ON (("player1"."teamId" = "team"."id") AND ("player1"."score" < 500)) \
                LEFT JOIN "player" "player2" ON (("player2"."teamId" = "team"."id") AND ("player2"."score" >= 500)) \
                GROUP BY "team"."id" \
                ORDER BY "team"."id"
                """)
            
            let teamInfos = try request.fetchAll(db)
            XCTAssertEqual(teamInfos.count, 3)
            
            XCTAssertEqual(teamInfos[0].team.id, 1)
            XCTAssertEqual(teamInfos[0].team.name, "Reds")
            XCTAssertEqual(teamInfos[0].lowPlayerCount, 1)
            XCTAssertEqual(teamInfos[0].highPlayerCount, 1)

            XCTAssertEqual(teamInfos[1].team.id, 2)
            XCTAssertEqual(teamInfos[1].team.name, "Blues")
            XCTAssertEqual(teamInfos[1].lowPlayerCount, 1)
            XCTAssertEqual(teamInfos[1].highPlayerCount, 2)

            XCTAssertEqual(teamInfos[2].team.id, 3)
            XCTAssertEqual(teamInfos[2].team.name, "Greens")
            XCTAssertEqual(teamInfos[2].lowPlayerCount, 0)
            XCTAssertEqual(teamInfos[2].highPlayerCount, 0)
        }
    }
    
    func testIsEmpty() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.isEmpty)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") = 0)
                    """)
            }
            do {
                let request = Team.having(!Team.players.isEmpty)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") > 0)
                    """)
            }
            do {
                let request = Team.having(Team.players.isEmpty == false)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") > 0)
                    """)
            }
            do {
                let request = Team.having(Team.players.isEmpty == true)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") = 0)
                    """)
            }
        }
    }
    
    func testEqualOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count == 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") = 2)
                    """)
            }
            do {
                let request = Team.having(2 == Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 = COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count == Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") = COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testNotEqualOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count != 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") <> 2)
                    """)
            }
            do {
                let request = Team.having(2 != Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 <> COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count != Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") <> COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testGreaterThanOrEqualOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count >= 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") >= 2)
                    """)
            }
            do {
                let request = Team.having(2 >= Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 >= COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count >= Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") >= COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testGreaterThanOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count > 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") > 2)
                    """)
            }
            do {
                let request = Team.having(2 > Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 > COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count > Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") > COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testLessThanOrEqualOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count <= 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") <= 2)
                    """)
            }
            do {
                let request = Team.having(2 <= Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 <= COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count <= Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") <= COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testLessThanOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.count < 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") < 2)
                    """)
            }
            do {
                let request = Team.having(2 < Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (2 < COUNT(DISTINCT "player"."rowid"))
                    """)
            }
            do {
                let request = Team.having(Team.players.count < Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING (COUNT(DISTINCT "player"."rowid") < COUNT(DISTINCT "award"."rowid"))
                    """)
            }
        }
    }
    
    func testLogicalOperators() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.having(Team.players.isEmpty && Team.awards.isEmpty)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING ((COUNT(DISTINCT "player"."rowid") = 0) AND (COUNT(DISTINCT "award"."rowid") = 0))
                    """)
            }
            do {
                let request = Team.having(Team.players.isEmpty || Team.awards.isEmpty)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING ((COUNT(DISTINCT "player"."rowid") = 0) OR (COUNT(DISTINCT "award"."rowid") = 0))
                    """)
            }
            do {
                let request = Team.having(!(Team.players.isEmpty || Team.awards.isEmpty))
                
                try assertEqualSQL(db, request, """
                    SELECT "team".* \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id" \
                    HAVING NOT ((COUNT(DISTINCT "player"."rowid") = 0) OR (COUNT(DISTINCT "award"."rowid") = 0))
                    """)
            }
        }
    }
    
    func testNegatedOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.annotated(with: -Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, -COUNT(DISTINCT "player"."rowid") \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
        }
    }

    func testAdditionOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.annotated(with: Team.players.count + 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") + 2) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: 2 + Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (2 + COUNT(DISTINCT "player"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: Team.players.count + Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") + COUNT(DISTINCT "award"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
        }
    }
    
    func testSubtractionOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.annotated(with: Team.players.count - 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") - 2) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: 2 - Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (2 - COUNT(DISTINCT "player"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: Team.players.count - Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") - COUNT(DISTINCT "award"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
        }
    }
    
    func testMultiplicationOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.annotated(with: Team.players.count * 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") * 2) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: 2 * Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (2 * COUNT(DISTINCT "player"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: Team.players.count * Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") * COUNT(DISTINCT "award"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
        }
    }
    
    func testDivisionOperator() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            do {
                let request = Team.annotated(with: Team.players.count / 2)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") / 2) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: 2 / Team.players.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (2 / COUNT(DISTINCT "player"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
            do {
                let request = Team.annotated(with: Team.players.count / Team.awards.count)
                
                try assertEqualSQL(db, request, """
                    SELECT "team".*, (COUNT(DISTINCT "player"."rowid") / COUNT(DISTINCT "award"."rowid")) \
                    FROM "team" \
                    LEFT JOIN "player" ON ("player"."teamId" = "team"."id") \
                    LEFT JOIN "award" ON ("award"."teamId" = "team"."id") \
                    GROUP BY "team"."id"
                    """)
            }
        }
    }
}
