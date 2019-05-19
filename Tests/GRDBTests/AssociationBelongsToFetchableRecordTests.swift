import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Team: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "teams"
    var id: Int64
    var name: String
}

private struct Player: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "players"
    static let teamScope = "team"
    static let team = Player.belongsTo(Team.self, key: teamScope)
    var id: Int64
    var teamId: Int64?
    var name: String
}

private struct PlayerWithRequiredTeam: FetchableRecord {
    var player: Player
    var team: Team
    
    init(row: Row) {
        player = Player(row: row)
        team = row[Player.teamScope]
    }
}

private struct PlayerWithOptionalTeam: FetchableRecord {
    var player: Player
    var team: Team?
    
    init(row: Row) {
        player = Player(row: row)
        team = row[Player.teamScope]
    }
}

/// Test support for FetchableRecord records
class AssociationBelongsToFetchableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "teams") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "players") { t in
                t.column("id", .integer).primaryKey()
                t.column("teamId", .integer).references("teams")
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
            .including(required: Player.team)
            .asRequest(of: PlayerWithRequiredTeam.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].player.id, 1)
        XCTAssertEqual(records[0].player.teamId, 1)
        XCTAssertEqual(records[0].player.name, "Arthur")
        XCTAssertEqual(records[0].team.id, 1)
        XCTAssertEqual(records[0].team.name, "Reds")
    }
    
    func testIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .including(optional: Player.team)
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
}
