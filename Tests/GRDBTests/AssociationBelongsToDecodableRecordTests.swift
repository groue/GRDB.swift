import XCTest
import GRDB

private struct Team: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "teams"
    var id: Int64
    var name: String
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }
}

private struct Player: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "players"
    static let team = Player.belongsTo(Team.self)
    var id: Int64
    var teamId: Int64?
    var name: String
    
    enum Columns {
        static let name = Column(CodingKeys.name)
    }
}

private struct PlayerWithRequiredTeam: Decodable, FetchableRecord {
    var player: Player
    var team: Team
    static let team = Player.team.forKey(CodingKeys.team)
}

private struct PlayerWithOptionalTeam: Decodable, FetchableRecord {
    var player: Player
    var team: Team?
    static let team = Player.team.forKey(CodingKeys.team)
}

private struct PlayerWithTeamName: Decodable, FetchableRecord {
    var player: Player
    var teamName: String?
}

private extension QueryInterfaceRequest<Player> {
    func filter(teamName: String) -> QueryInterfaceRequest<Player> {
        joining(required: PlayerWithOptionalTeam.team.filter { $0.name == teamName })
    }
    
    func orderedByTeamName() -> QueryInterfaceRequest<Player> {
        let teamAlias = TableAlias()
        return self
            .joining(optional: PlayerWithOptionalTeam.team.aliased(teamAlias))
            .order { [teamAlias[Team.Columns.name], $0.name] }
    }
    
    func orderedByTeamName_swift61() -> QueryInterfaceRequest<Player> {
        let teamAlias = TableAlias<Team>()
        return self
            .joining(optional: PlayerWithOptionalTeam.team.aliased(teamAlias))
            .order { [teamAlias.name, $0.name] }
    }
}

/// Test support for Decodable records
class AssociationBelongsToDecodableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "teams") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text)
            }
            try db.create(table: "players") { t in
                t.primaryKey("id", .integer)
                t.belongsTo("team")
                t.column("name", .text)
            }
            
            try Team(id: 1, name: "Reds").insert(db)
            try Player(id: 1, teamId: 1, name: "Arthur").insert(db)
            try Player(id: 2, teamId: nil, name: "Barbara").insert(db)
        }
    }
    
    func testIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .including(required: PlayerWithRequiredTeam.team)
            .asRequest(of: PlayerWithRequiredTeam.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].team.id, 1)
        XCTAssertEqual(records[0].team.name, "Reds")
    }
    
    func testAnnotatedWithRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .annotated(withRequired: Player.team.select { $0.name.forKey("teamName") })
            .asRequest(of: PlayerWithTeamName.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].teamName, "Reds")
    }
    
    func testIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .including(optional: PlayerWithOptionalTeam.team)
            .asRequest(of: PlayerWithOptionalTeam.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].team!.id, 1)
        XCTAssertEqual(records[0].team!.name, "Reds")
        XCTAssertEqual(records[1].player.id, 2)
        XCTAssertNil(records[1].player.teamId)
        XCTAssertEqual(records[1].player.name, "Barbara")
        XCTAssertNil(records[1].team)
    }
    
    func testAnnotatedWithOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .annotated(withOptional: Player.team.select { $0.name.forKey("teamName") })
            .asRequest(of: PlayerWithTeamName.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].teamName, "Reds")
        XCTAssertEqual(records[1].player.id, 2)
        XCTAssertEqual(records[1].player.name, "Barbara")
        XCTAssertNil(records[1].teamName)
    }
    
    func testJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(required: Player.team)
        let players = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(players.count, 1)
        XCTAssertEqual(players[0].id, 1)
        XCTAssertEqual(players[0].teamId, 1)
        XCTAssertEqual(players[0].name, "Arthur")
    }
    
    func testJoiningsOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player.joining(optional: Player.team)
        let players = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(players.count, 2)
        XCTAssertEqual(players[0].id, 1)
        XCTAssertEqual(players[0].teamId, 1)
        XCTAssertEqual(players[0].name, "Arthur")
        XCTAssertEqual(players[1].id, 2)
        XCTAssertNil(players[1].teamId)
        XCTAssertEqual(players[1].name, "Barbara")
    }
    
    func testRequestRefining() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .including(required: PlayerWithRequiredTeam.team.select { [$0.name, $0.id] })
            .filter(teamName: "Reds")
            .orderedByTeamName()
            .asRequest(of: PlayerWithRequiredTeam.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(lastSQLQuery, """
            SELECT "players".*, "teams"."name", "teams"."id" \
            FROM "players" \
            JOIN "teams" ON ("teams"."id" = "players"."teamId") AND ("teams"."name" = 'Reds') \
            ORDER BY "teams"."name", "players"."name"
            """)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].team.id, 1)
        XCTAssertEqual(records[0].team.name, "Reds")
    }
    
    func testRequestRefining_swift61() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .including(required: PlayerWithRequiredTeam.team.select { [$0.name, $0.id] })
            .filter(teamName: "Reds")
            .orderedByTeamName_swift61()
            .asRequest(of: PlayerWithRequiredTeam.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(lastSQLQuery, """
            SELECT "players".*, "teams"."name", "teams"."id" \
            FROM "players" \
            JOIN "teams" ON ("teams"."id" = "players"."teamId") AND ("teams"."name" = 'Reds') \
            ORDER BY "teams"."name", "players"."name"
            """)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].team.id, 1)
        XCTAssertEqual(records[0].team.name, "Reds")
    }
}
