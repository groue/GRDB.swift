import Query
import GRDB

struct PlayerRequest: Queryable {
    static var defaultValue: Player? { nil }
    
    func publisher(in dbQueue: DatabaseQueue) -> DatabasePublishers.Value<Player?> {
        ValueObservation
            .tracking(Player.fetchOne)
            .publisher(in: dbQueue, scheduling: .immediate)
    }
}
