import Testing
import GRDB
@testable import GRDBDemo

struct PlayerListModelTests {
    // MARK: - PlayerListModel.observePlayers tests
    
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_started_after_player_creation() async throws {
        // Given a PlayerListModel on a database that contains a player
        let (appDatabase, _) = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase)
        
        // When we start observing the database
        model.observePlayers()
        
        // Then the model eventually fetches the player.
        // We poll because we do not know when the model will update its players.
        await pollUntil {
            model.players.isEmpty == false
        }
        #expect(model.players == [player])
    }
    
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_started_before_player_creation() async throws {
        // Given a PlayerListModel that observes a empty database
        let (appDatabase, _) = try makeEmptyTestDatabase()
        let model = PlayerListModel(appDatabase: appDatabase)
        model.observePlayers()
        
        // When we insert a player
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        
        // Then the model eventually fetches the player.
        // We poll because we do not know when the model will update its players.
        await pollUntil {
            model.players.isEmpty == false
        }
        #expect(model.players == [player])
    }
    
    @Test
    @MainActor func test_deleteAllPlayers_deletes_players_in_the_database() async throws {
        // Given a PlayerListModel on a database that contains a player
        let (appDatabase, dbQueue) = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase)
        
        // When we delete all players
        try model.deleteAllPlayers()
        
        // Then the database is empty.
        let playerCount = try await dbQueue.read { db in
            try Player.fetchCount(db)
        }
        #expect(playerCount == 0)
    }
    
    /// Returns an `AppDatabase`, and its underlying database connection.
    private func makeEmptyTestDatabase() throws -> (AppDatabase, DatabaseQueue) {
        let config = AppDatabase.makeConfiguration()
        let dbQueue = try DatabaseQueue(configuration: config)
        let appDatabase = try AppDatabase(dbQueue)
        return (appDatabase, dbQueue)
    }
    
    /// Convenience method that loops until a condition is met.
    private func pollUntil(condition: @escaping @MainActor () async -> Bool) async {
        await confirmation { confirmation in
            while true {
                if await condition() {
                    confirmation()
                    return
                } else {
                    await Task.yield()
                }
            }
        }
    }
}
