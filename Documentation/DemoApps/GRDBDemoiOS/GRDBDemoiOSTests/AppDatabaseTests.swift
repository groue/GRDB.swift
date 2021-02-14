import XCTest
import GRDB
@testable import GRDBDemoiOS

class AppDatabaseTests: XCTestCase {
    func test_database_schema() throws {
        // Given an empty database
        let dbQueue = DatabaseQueue()
        
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
    
    func test_savePlayer_inserts() throws {
        // Given an empty players database
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we save a new player
        var player = Player(id: nil, name: "Arthur", score: 100)
        try appDatabase.savePlayer(&player)
        
        // Then the player exists in the database
        try XCTAssertTrue(dbQueue.read(player.exists))
    }
    
    func test_savePlayer_updates() throws {
        // Given a players database that contains a player
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player = Player(id: nil, name: "Arthur", score: 100)
        try dbQueue.write { db in
            try player.insert(db)            
        }
        
        // When we modify and save the player
        player.name = "Barbara"
        player.score = 1000
        try appDatabase.savePlayer(&player)
        
        // Then the player has been updated in the database
        let fetchedPlayer = try dbQueue.read { db in
            try XCTUnwrap(Player.fetchOne(db, key: player.id))
        }
        XCTAssertEqual(fetchedPlayer, player)
    }
    
    func test_deletePlayers() throws {
        // Given a players database that contains four players
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 200)
        var player3 = Player(id: nil, name: "Craig", score: 150)
        var player4 = Player(id: nil, name: "David", score: 120)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
            try player3.insert(db)
            try player4.insert(db)
        }
        
        // When we delete two players
        try appDatabase.deletePlayers(ids: [player1.id!, player3.id!])
        
        // Then the deleted players no longer exist
        try dbQueue.read { db in
            try XCTAssertFalse(player1.exists(db))
            try XCTAssertFalse(player3.exists(db))
        }
        
        // Then the database still contains two players
        try XCTAssertEqual(dbQueue.read(Player.fetchCount), 2)
    }
    
    func test_deleteAllPlayers() throws {
        // Given a players database that contains players
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 200)
        var player3 = Player(id: nil, name: "Craig", score: 150)
        var player4 = Player(id: nil, name: "David", score: 120)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
            try player3.insert(db)
            try player4.insert(db)
        }
        
        // When we delete all players
        try appDatabase.deleteAllPlayers()
        
        // Then the database does not contain any player
        try XCTAssertEqual(dbQueue.read(Player.fetchCount), 0)
    }
    
    func test_refreshPlayers_populates_an_empty_database() throws {
        // Given an empty players database
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we refresh players
        try appDatabase.refreshPlayers()
        
        // Then the database is not empty
        try XCTAssert(dbQueue.read(Player.fetchCount) > 0)
    }
    
    func test_createRandomPlayersIfEmpty_populates_an_empty_database() throws {
        // Given an empty players database
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        
        // When we create random players
        try appDatabase.createRandomPlayersIfEmpty()
        
        // Then the database is not empty
        try XCTAssert(dbQueue.read(Player.fetchCount) > 0)
    }
    
    func test_createRandomPlayersIfEmpty_does_not_modify_a_non_empty_database() throws {
        // Given a players database that contains one player
        let dbQueue = DatabaseQueue()
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
    
    func test_observePlayersOrderedByName() throws {
        // Given a players database that contains two players
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 1000)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        // When we observe players and wait for the first value
        let exp = expectation(description: "Players")
        var players: [Player]?
        let cancellable = appDatabase.observePlayersOrderedByName(
            onError: { error in
                XCTFail("Unexpected error \(error)")
            },
            onChange: {
                players = $0
                exp.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        // Then the players are the two players ordered by name
        XCTAssertEqual(players, [player1, player2])
    }
    
    func test_observePlayersOrderedByScore() throws {
        // Given a players database that contains two players
        let dbQueue = DatabaseQueue()
        let appDatabase = try AppDatabase(dbQueue)
        var player1 = Player(id: nil, name: "Arthur", score: 100)
        var player2 = Player(id: nil, name: "Barbara", score: 1000)
        try dbQueue.write { db in
            try player1.insert(db)
            try player2.insert(db)
        }
        
        // When we observe players and wait for the first value
        let exp = expectation(description: "Players")
        var players: [Player]?
        let cancellable = appDatabase.observePlayersOrderedByScore(
            onError: { error in
                XCTFail("Unexpected error \(error)")
            },
            onChange: {
                players = $0
                exp.fulfill()
            })
        withExtendedLifetime(cancellable) {
            waitForExpectations(timeout: 1, handler: nil)
        }
        
        // Then the players are the two players ordered by score descending
        XCTAssertEqual(players, [player2, player1])
    }
}
