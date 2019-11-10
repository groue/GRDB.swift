import XCTest
#if GRDBCUSTOMSQLITE
import GRDBCustomSQLite
#else
import GRDB
#endif

// Ordered hasManyThrough
private struct Team: Codable, FetchableRecord, PersistableRecord, Equatable {
    static let players = hasMany(Player.self).order(Column("position"))
    var id: Int64
    var name: String
}

private struct Player: Codable, FetchableRecord, PersistableRecord, Equatable {
    var id: Int64
    var teamId: Int64
    var name: String
    var position: Int
}

private struct TeamInfo: Decodable, FetchableRecord, Equatable {
    var team: Team
    var players: [Player]
}

/// A usage test for ordered hasMany association
class AssociationHasManyOrderingTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "team") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text).notNull()
            }
            try db.create(table: "player") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).notNull().references("team")
                t.column("name", .text).notNull()
                t.column("position", .integer).notNull()
            }
            
            try Team(id: 1, name: "Red").insert(db)
            try Team(id: 2, name: "Blue").insert(db)
            try Player(id: 1, teamId: 1, name: "Arthur", position: 1).insert(db)
            try Player(id: 2, teamId: 1, name: "Barbara", position: 2).insert(db)
            try Player(id: 3, teamId: 1, name: "Craig", position: 3).insert(db)
            try Player(id: 4, teamId: 2, name: "Diane", position: 3).insert(db)
            try Player(id: 5, teamId: 2, name: "Eugene", position: 2).insert(db)
            try Player(id: 6, teamId: 2, name: "Fiona", position: 1).insert(db)
        }
    }
    
    func testRequestFor() throws {
        try makeDatabaseQueue().read { db in
            let team = try Team.fetchOne(db, key: 2)!
            let players = try team.request(for: Team.players).fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "player" WHERE "teamId" = 2 ORDER BY "position"
                """)
            XCTAssertEqual(players, [
                Player(id: 6, teamId: 2, name: "Fiona", position: 1),
                Player(id: 5, teamId: 2, name: "Eugene", position: 2),
                Player(id: 4, teamId: 2, name: "Diane", position: 3),
            ])
        }
    }
    
    func testReorderedRequestFor() throws {
        try makeDatabaseQueue().read { db in
            let team = try Team.fetchOne(db, key: 2)!
            let players = try team.request(for: Team.players).order(Column("name")).fetchAll(db)
            XCTAssertEqual(lastSQLQuery, """
                SELECT * FROM "player" WHERE "teamId" = 2 ORDER BY "name"
                """)
            XCTAssertEqual(players, [
                Player(id: 4, teamId: 2, name: "Diane", position: 3),
                Player(id: 5, teamId: 2, name: "Eugene", position: 2),
                Player(id: 6, teamId: 2, name: "Fiona", position: 1),
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
                SELECT *, "teamId" AS "grdb_teamId" \
                FROM "player" \
                WHERE "teamId" IN (1, 2) \
                ORDER BY "position"
                """))
            XCTAssertEqual(teamInfos, [
                TeamInfo(
                    team: Team(id: 1, name: "Red"),
                    players: [
                        Player(id: 1, teamId: 1, name: "Arthur", position: 1),
                        Player(id: 2, teamId: 1, name: "Barbara", position: 2),
                        Player(id: 3, teamId: 1, name: "Craig", position: 3),
                ]),
                TeamInfo(
                    team: Team(id: 2, name: "Blue"),
                    players: [
                        Player(id: 6, teamId: 2, name: "Fiona", position: 1),
                        Player(id: 5, teamId: 2, name: "Eugene", position: 2),
                        Player(id: 4, teamId: 2, name: "Diane", position: 3),
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
                SELECT *, "teamId" AS "grdb_teamId" \
                FROM "player" \
                WHERE "teamId" IN (1, 2) \
                ORDER BY "name"
                """))
            XCTAssertEqual(teamInfos, [
                TeamInfo(
                    team: Team(id: 1, name: "Red"),
                    players: [
                        Player(id: 1, teamId: 1, name: "Arthur", position: 1),
                        Player(id: 2, teamId: 1, name: "Barbara", position: 2),
                        Player(id: 3, teamId: 1, name: "Craig", position: 3),
                ]),
                TeamInfo(
                    team: Team(id: 2, name: "Blue"),
                    players: [
                        Player(id: 4, teamId: 2, name: "Diane", position: 3),
                        Player(id: 5, teamId: 2, name: "Eugene", position: 2),
                        Player(id: 6, teamId: 2, name: "Fiona", position: 1),
                ])])
        }
    }
}
