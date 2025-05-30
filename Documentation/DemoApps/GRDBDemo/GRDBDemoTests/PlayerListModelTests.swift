import Testing
import GRDB
@testable import GRDBDemo

struct PlayerListModelTests {
    // MARK: - PlayerListModel.observePlayers tests
    
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_current_database_state() async throws {
        // Given a PlayerListModel on a database that contains one player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase)
        
        // When the model starts observing the database
        model.observePlayers()
        
        // Then the model eventually has one player.
        try await pollUntil { model.players.count == 1 }
    }
    
    @Test(.timeLimit(.minutes(1)))
    @MainActor func observation_grabs_database_changes() async throws {
        // Given a PlayerListModel that has one player
        let appDatabase = try makeEmptyTestDatabase()
        var player1 = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player1)
        let model = PlayerListModel(appDatabase: appDatabase)
        model.observePlayers()
        try await pollUntil { model.players.count == 1 }
        
        // When we insert a second player
        var player2 = Player(name: "Barbara", score: 800)
        try appDatabase.savePlayer(&player2)
        
        // Then the model eventually has two players.
        try await pollUntil { model.players.count == 2 }
    }
    
    @Test
    @MainActor func test_deleteAllPlayers_deletes_players_in_the_database() async throws {
        // Given a PlayerListModel on a database that contains a player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        let model = PlayerListModel(appDatabase: appDatabase)
        
        // When we delete all players
        try model.deleteAllPlayers()
        
        // Then the database is empty.
        let playerCount = try await appDatabase.reader.read { db in
            try Player.fetchCount(db)
        }
        #expect(playerCount == 0)
    }
    
    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }
    
    /// Convenience method that loops until a condition is met.
    private func pollUntil(condition: @escaping @MainActor () async -> Bool) async throws {
        try await confirmation { confirmation in
            while true {
                if await condition() {
                    confirmation()
                    return
                } else {
                    try await Task.sleep(for: .seconds(0.01))
                }
            }
        }
    }
}
