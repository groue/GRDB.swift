import Query
import GRDB

/// A @Query request that observes the number of players in the database
struct PlayerCountRequest: Queryable {
    static var defaultValue: Int { 0 }
    
    func publisher(in dbQueue: DatabaseQueue) -> DatabasePublishers.Value<Int> {
        ValueObservation
            .tracking(Player.fetchCount)
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}
