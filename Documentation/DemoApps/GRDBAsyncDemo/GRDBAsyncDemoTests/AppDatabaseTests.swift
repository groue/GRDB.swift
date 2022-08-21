import XCTest
import GRDB
@testable import GRDBAsyncDemo

class AppDatabaseTests: XCTestCase {
    func test_database_schema() throws {
        // Given an empty database
        let dbQueue = try DatabaseQueue()
        
        // When we instantiate an AppDatabase
        _ = try AppDatabase(dbQueue)
        
        // Then the player table exists, with id, name & score columns
        try dbQueue.read { db in
            try XCTAssert(db.tableExists("player"))
            let columns = try db.columns(in: "player")
            let columnNames = Set(columns.map { $0.name })
            XCTAssertEqual(columnNames, ["id", "name", "score"])
        }
    }
    
    func test_savePlayer_inserts() async throws {
        // Given an empty players database
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we save a new player
        var player = Player(id: nil, name: "Arthur", score: 100)
        try await appDatabase.savePlayer(&player)
        
        // Then the player exists in the database
        let playerExists = try await dbQueue.read { [player] in try player.exists($0) }
        XCTAssertTrue(playerExists)
    }
    
    func test_savePlayer_updates() async throws {
        // Given a players database that contains a player
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player = try await dbQueue.write { db in
            try Player(id: nil, name: "Arthur", score: 100).inserted(db)
        }
        
        // When we modify and save the player
        player.name = "Barbara"
        player.score = 1000
        try await appDatabase.savePlayer(&player)
        
        // Then the player has been updated in the database
        let fetchedPlayer = try await dbQueue.read { [player] db in
            try XCTUnwrap(Player.fetchOne(db, key: player.id))
        }
        XCTAssertEqual(fetchedPlayer, player)
    }
    
    func test_deletePlayers() async throws {
        // Given a players database that contains four players
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        let playerIds: [Int64] = try await dbQueue.write { db in
            _ = try Player(id: nil, name: "Arthur", score: 100).inserted(db)
            _ = try Player(id: nil, name: "Barbara", score: 200).inserted(db)
            _ = try Player(id: nil, name: "Craig", score: 150).inserted(db)
            _ = try Player(id: nil, name: "David", score: 120).inserted(db)
            return try Player.selectPrimaryKey().fetchAll(db)
        }
        
        // When we delete two players
        let deletedId1 = playerIds[0]
        let deletedId2 = playerIds[2]
        try await appDatabase.deletePlayers(ids: [deletedId1, deletedId2])
        
        // Then the deleted players no longer exist
        try await dbQueue.read { db in
            try XCTAssertFalse(Player.exists(db, id: deletedId1))
            try XCTAssertFalse(Player.exists(db, id: deletedId2))
        }
        
        // Then the database still contains two players
        let count = try await dbQueue.read { try Player.fetchCount($0) }
        XCTAssertEqual(count, 2)
    }
    
    func test_deleteAllPlayers() async throws {
        // Given a players database that contains players
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        try await dbQueue.write { db in
            _ = try Player(id: nil, name: "Arthur", score: 100).inserted(db)
            _ = try Player(id: nil, name: "Barbara", score: 200).inserted(db)
            _ = try Player(id: nil, name: "Craig", score: 150).inserted(db)
            _ = try Player(id: nil, name: "David", score: 120).inserted(db)
        }
        
        // When we delete all players
        try await appDatabase.deleteAllPlayers()
        
        // Then the database does not contain any player
        let count = try await dbQueue.read { try Player.fetchCount($0) }
        XCTAssertEqual(count, 0)
    }
    
    func test_refreshPlayers_populates_an_empty_database() async throws {
        // Given an empty players database
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we refresh players
        try await appDatabase.refreshPlayers()
        
        // Then the database is not empty
        let count = try await dbQueue.read { try Player.fetchCount($0) }
        XCTAssert(count > 0)
    }
    
    func test_createRandomPlayersIfEmpty_populates_an_empty_database() throws {
        // Given an empty players database
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we create random players
        try appDatabase.createRandomPlayersIfEmpty()
        
        // Then the database is not empty
        try XCTAssert(dbQueue.read(Player.fetchCount) > 0)
    }
    
    func test_createRandomPlayersIfEmpty_does_not_modify_a_non_empty_database() throws {
        // Given a players database that contains one player
        let dbQueue = try DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player = Player(id: nil, name: "Arthur", score: 100)
        try dbQueue.write { db in
            try player.insert(db)
        }
        
        // When we create random players
        try appDatabase.createRandomPlayersIfEmpty()
        
        // Then the database still only contains the original player
        let players = try dbQueue.read(Player.fetchAll)
        XCTAssertEqual(players, [player])
    }
}
