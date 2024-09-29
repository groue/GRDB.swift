import Testing
import GRDB
@testable import GRDBDemo

struct AppDatabaseTests {
    @Test func insert() throws {
        // Given an empty database
        let appDatabase = try makeEmptyTestDatabase()
        
        // When we insert a player
        var insertedPlayer = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&insertedPlayer)
        
        // Then the inserted player has an id
        #expect(insertedPlayer.id != nil)
        
        // Then the inserted player exists in the database
        let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne)
        #expect(fetchedPlayer == insertedPlayer)
    }
    
    @Test func update() throws {
        // Given a database that contains a player
        let appDatabase = try makeEmptyTestDatabase()
        var insertedPlayer = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&insertedPlayer)
        
        // When we update a player
        var updatedPlayer = insertedPlayer
        updatedPlayer.name = "Barbara"
        updatedPlayer.score = 0
        try appDatabase.savePlayer(&updatedPlayer)
        
        // Then the player is updated
        let fetchedPlayer = try appDatabase.reader.read(Player.fetchOne)
        #expect(fetchedPlayer == updatedPlayer)
    }
    
    @Test func deleteAll() throws {
        // Given a database that contains a player
        let appDatabase = try makeEmptyTestDatabase()
        var player = Player(name: "Arthur", score: 1000)
        try appDatabase.savePlayer(&player)
        
        // When we delete all players
        try appDatabase.deleteAllPlayers()
        
        // Then no player exists
        let count = try appDatabase.reader.read(Player.fetchCount(_:))
        #expect(count == 0)
    }
    
    /// Return an empty, in-memory, `AppDatabase`.
    private func makeEmptyTestDatabase() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: AppDatabase.makeConfiguration())
        return try AppDatabase(dbQueue)
    }
}
