import Query
import GRDB

/// A @Query request that observes the player (any player, actually) in the database
struct PlayerRequest: Queryable {
    static var defaultValue: Player? { nil }
    
    func publisher(in dbQueue: DatabaseQueue) -> DatabasePublishers.Value<Player?> {
        ValueObservation
            .tracking(Player.fetchOne)
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}
