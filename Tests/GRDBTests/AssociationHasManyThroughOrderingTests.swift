import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// Ordered hasManyThrough
private struct Team: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let playerRoles = hasMany(PlayerRole.self).order(Column("position"))
    static let players = hasMany(Player.self, through: playerRoles, using: PlayerRole.player)
    var id: Int64
    var name: String
}

private struct PlayerRole: Codable, FetchableRecord, PersistableRecord {
    static let player = belongsTo(Player.self)
    var teamId: Int64
    var playerId: Int64
    var position: Int
}

private struct Player: Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: Int64
    var name: String
}

private struct TeamInfo: Decodable, FetchableRecord, Equatable {
    var team: Team
    var players: [Player]
}

/// A usage test for ordered hasManyThrough association
class AssociationHasManyThroughOrderingTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "team") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
            }
            try db.create(table: "player") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
            }
            try db.create(table: "playerRole") { t in
                t.column("teamId", .integer).notNull().references("team")
                t.column("playerId", .integer).notNull().references("player")
                t.column("position", .integer).notNull()
                t.primaryKey(["teamId", "playerId"])
            }

            try Team(id: 1, name: "Red").insert(db)
            try Team(id: 2, name: "Blue").insert(db)
            try Player(id: 1, name: "Arthur").insert(db)
            try Player(id: 2, name: "Barbara").insert(db)
            try Player(id: 3, name: "Craig").insert(db)
            try Player(id: 4, name: "Diane").insert(db)
            try PlayerRole(teamId: 1, playerId: 1, position: 1).insert(db)
            try PlayerRole(teamId: 1, playerId: 2, position: 2).insert(db)
            try PlayerRole(teamId: 1, playerId: 3, position: 3).insert(db)
            try PlayerRole(teamId: 2, playerId: 2, position: 3).insert(db)
            try PlayerRole(teamId: 2, playerId: 3, position: 2).insert(db)
            try PlayerRole(teamId: 2, playerId: 4, position: 1).insert(db)
        }
    }
    
    func testRequestFor() throws {
        try makeDatabaseQueue().read { db in
            let team = try Team.fetchOne(db, key: 2)!
            let players = try team.request(for: Team.players).fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT "player".* \
                FROM "player" \
                JOIN "playerRole" ON ("playerRole"."playerId" = "player"."id") AND ("playerRole"."teamId" = 2) \
                ORDER BY "playerRole"."position"
                """)
            XCTAssertEqual(players, [
                Player(id: 4, name: "Diane"),
                Player(id: 3, name: "Craig"),
                Player(id: 2, name: "Barbara"),
            ])
        }
    }
    
    func testReorderedRequestFor() throws {
        try makeDatabaseQueue().read { db in
            let team = try Team.fetchOne(db, key: 2)!
            let players = try team.request(for: Team.players).order(Column("name")).fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT "player".* \
                FROM "player" \
                JOIN "playerRole" ON ("playerRole"."playerId" = "player"."id") AND ("playerRole"."teamId" = 2) \
                ORDER BY "player"."name", "playerRole"."position"
                """)
            XCTAssertEqual(players, [
                Player(id: 2, name: "Barbara"),
                Player(id: 3, name: "Craig"),
                Player(id: 4, name: "Diane"),
            ])
        }
    }
    
    func testIncludingAll() throws {
        try makeDatabaseQueue().read { db in
            let teamInfos = try Team
                .orderByPrimaryKey()
                .including(all: Team.players)
                .asRequest(of: TeamInfo.self)
                .fetchAll(db)
            XCTAssertTrue(sqlQueries.contains("""
                SELECT * FROM "team" ORDER BY "id"
                """))
            XCTAssertTrue(sqlQueries.contains("""
                SELECT "player".*, "playerRole"."teamId" AS "grdb_teamId" \
                FROM "player" \
                JOIN "playerRole" ON ("playerRole"."playerId" = "player"."id") AND ("playerRole"."teamId" IN (1, 2)) \
                ORDER BY "playerRole"."position"
                """))
            XCTAssertEqual(teamInfos, [
                TeamInfo(
                    team: Team(id: 1, name: "Red"),
                    players: [
                        Player(id: 1, name: "Arthur"),
                        Player(id: 2, name: "Barbara"),
                        Player(id: 3, name: "Craig"),
                ]),
                TeamInfo(
                    team: Team(id: 2, name: "Blue"),
                    players: [
                        Player(id: 4, name: "Diane"),
                        Player(id: 3, name: "Craig"),
                        Player(id: 2, name: "Barbara"),
                ])])
        }
    }
    
    func testReorderedIncludingAll() throws {
        try makeDatabaseQueue().read { db in
            let teamInfos = try Team
                .orderByPrimaryKey()
                .including(all: Team.players.order(Column("name")))
                .asRequest(of: TeamInfo.self)
                .fetchAll(db)
            XCTAssertTrue(sqlQueries.contains("""
                SELECT * FROM "team" ORDER BY "id"
                """))
            XCTAssertTrue(sqlQueries.contains("""
                SELECT "player".*, "playerRole"."teamId" AS "grdb_teamId" \
                FROM "player" \
                JOIN "playerRole" ON ("playerRole"."playerId" = "player"."id") AND ("playerRole"."teamId" IN (1, 2)) \
                ORDER BY "player"."name", "playerRole"."position"
                """))
            XCTAssertEqual(teamInfos, [
                TeamInfo(
                    team: Team(id: 1, name: "Red"),
                    players: [
                        Player(id: 1, name: "Arthur"),
                        Player(id: 2, name: "Barbara"),
                        Player(id: 3, name: "Craig"),
                ]),
                TeamInfo(
                    team: Team(id: 2, name: "Blue"),
                    players: [
                        Player(id: 2, name: "Barbara"),
                        Player(id: 3, name: "Craig"),
                        Player(id: 4, name: "Diane"),
                ])])
        }
    }
}
