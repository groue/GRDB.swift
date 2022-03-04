import XCTest
import GRDB

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
    
    init(row: Row) throws {
        player = try Player(row: row)
        team = try row[Player.teamScope]
    }
}

private struct PlayerWithOptionalTeam: FetchableRecord {
    var player: Player
    var team: Team?
    
    init(row: Row) throws {
        player = try Player(row: row)
        team = try row[Player.teamScope]
    }
}

private struct PlayerWithTeamName: FetchableRecord {
    var player: Player
    var teamName: String?
    
    init(row: Row) throws {
        player = try Player(row: row)
        teamName = try row["teamName"]
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
    
    func testAnnotatedWithRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .annotated(withRequired: Player.team.select(Column("name").forKey("teamName")))
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
    
    func testAnnotatedWithOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Player
            .annotated(withOptional: Player.team.select(Column("name").forKey("teamName")))
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
    
    func testJoiningOptional() throws {
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
    
    func testIncludingRequired_ColumnDecodingStrategy() throws {
        struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }
        
        struct XTeam: Decodable, FetchableRecord, TableRecord {
            static let databaseTableName = "teams"
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
                AnyKey(stringValue: "x\(column)")
            }
            var xid: Int64
            var xname: String
        }
        
        struct XPlayer: Decodable, FetchableRecord, TableRecord {
            static let databaseTableName = "players"
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
                AnyKey(stringValue: "x\(column)")
            }
            static let team = belongsTo(Team.self, key: "team")
            static let xteam = belongsTo(XTeam.self, key: "xteam")
            var xid: Int64
            var xteamId: Int64?
            var xname: String
        }
        
        do {
            struct XPlayerWithRequiredXTeam: Decodable, FetchableRecord {
                var xplayer: XPlayer
                var xteam: XTeam
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = XPlayer
                .including(required: XPlayer.xteam)
                .asRequest(of: XPlayerWithRequiredXTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].xplayer.xid, 1)
            XCTAssertEqual(records[0].xplayer.xteamId, 1)
            XCTAssertEqual(records[0].xplayer.xname, "Arthur")
            XCTAssertEqual(records[0].xteam.xid, 1)
            XCTAssertEqual(records[0].xteam.xname, "Reds")
        }
        
        do {
            struct XPlayerWithRequiredTeam: Decodable, FetchableRecord {
                var xplayer: XPlayer
                var team: Team
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = XPlayer
                .including(required: XPlayer.team)
                .asRequest(of: XPlayerWithRequiredTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].xplayer.xid, 1)
            XCTAssertEqual(records[0].xplayer.xteamId, 1)
            XCTAssertEqual(records[0].xplayer.xname, "Arthur")
            XCTAssertEqual(records[0].team.id, 1)
            XCTAssertEqual(records[0].team.name, "Reds")
        }
        
        do {
            struct PlayerWithRequiredXTeam: Decodable, FetchableRecord {
                var player: Player
                var xteam: XTeam
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = Player
                .including(required: Player.belongsTo(XTeam.self, key: "xteam"))
                .asRequest(of: PlayerWithRequiredXTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records[0].player.id, 1)
            XCTAssertEqual(records[0].player.teamId, 1)
            XCTAssertEqual(records[0].player.name, "Arthur")
            XCTAssertEqual(records[0].xteam.xid, 1)
            XCTAssertEqual(records[0].xteam.xname, "Reds")
        }
    }
    
    func testIncludingOptional_ColumnDecodingStrategy() throws {
        struct AnyKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }
        
        struct XTeam: Decodable, FetchableRecord, TableRecord {
            static let databaseTableName = "teams"
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
                AnyKey(stringValue: "x\(column)")
            }
            var xid: Int64
            var xname: String
        }
        
        struct XPlayer: Decodable, FetchableRecord, TableRecord {
            static let databaseTableName = "players"
            static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.custom { column in
                AnyKey(stringValue: "x\(column)")
            }
            static let team = belongsTo(Team.self, key: "team")
            static let xteam = belongsTo(XTeam.self, key: "xteam")
            var xid: Int64
            var xteamId: Int64?
            var xname: String
        }
        
        do {
            struct XPlayerWithOptionalXTeam: Decodable, FetchableRecord {
                var xplayer: XPlayer
                var xteam: XTeam?
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = XPlayer
                .including(optional: XPlayer.xteam)
                .asRequest(of: XPlayerWithOptionalXTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].xplayer.xid, 1)
            XCTAssertEqual(records[0].xplayer.xteamId, 1)
            XCTAssertEqual(records[0].xplayer.xname, "Arthur")
            XCTAssertEqual(records[0].xteam!.xid, 1)
            XCTAssertEqual(records[0].xteam!.xname, "Reds")
            XCTAssertEqual(records[1].xplayer.xid, 2)
            XCTAssertNil(records[1].xplayer.xteamId)
            XCTAssertEqual(records[1].xplayer.xname, "Barbara")
            XCTAssertNil(records[1].xteam)
        }
        
        do {
            struct XPlayerWithOptionalTeam: Decodable, FetchableRecord {
                var xplayer: XPlayer
                var team: Team?
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = XPlayer
                .including(optional: XPlayer.team)
                .asRequest(of: XPlayerWithOptionalTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].xplayer.xid, 1)
            XCTAssertEqual(records[0].xplayer.xteamId, 1)
            XCTAssertEqual(records[0].xplayer.xname, "Arthur")
            XCTAssertEqual(records[0].team!.id, 1)
            XCTAssertEqual(records[0].team!.name, "Reds")
            XCTAssertEqual(records[1].xplayer.xid, 2)
            XCTAssertNil(records[1].xplayer.xteamId)
            XCTAssertEqual(records[1].xplayer.xname, "Barbara")
            XCTAssertNil(records[1].team)
        }
        
        do {
            struct PlayerWithOptionalXTeam: Decodable, FetchableRecord {
                var player: Player
                var xteam: XTeam?
            }
            
            let dbQueue = try makeDatabaseQueue()
            let request = Player
                .including(optional: Player.belongsTo(XTeam.self, key: "xteam"))
                .asRequest(of: PlayerWithOptionalXTeam.self)
            let records = try dbQueue.inDatabase { try request.fetchAll($0) }
            XCTAssertEqual(records.count, 2)
            XCTAssertEqual(records[0].player.id, 1)
            XCTAssertEqual(records[0].player.teamId, 1)
            XCTAssertEqual(records[0].player.name, "Arthur")
            XCTAssertEqual(records[0].xteam!.xid, 1)
            XCTAssertEqual(records[0].xteam!.xname, "Reds")
            XCTAssertEqual(records[1].player.id, 2)
            XCTAssertNil(records[1].player.teamId)
            XCTAssertEqual(records[1].player.name, "Barbara")
            XCTAssertNil(records[1].xteam)
        }
    }
}
