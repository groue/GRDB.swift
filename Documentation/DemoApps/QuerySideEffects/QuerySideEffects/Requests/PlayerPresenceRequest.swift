import Combine
import GRDB
import Query

struct PlayerPresenceRequest: Queryable {
    static var defaultValue: PlayerPresence { .missing }
    
    var id: Int64
    
    func publisher(in dbQueue: DatabaseQueue) -> AnyPublisher<PlayerPresence, Error> {
        ValueObservation
            .tracking(Player.filter(id: id).fetchOne)
            .publisher(in: dbQueue, scheduling: .immediate)
            .scan(.missing) { (previous, player) in
                if let player = player {
                    return .existing(player)
                } else if let player = previous.player {
                    return .gone(player)
                } else {
                    return .missing
                }
            }
            .eraseToAnyPublisher()
    }
}

enum PlayerPresence {
    /// The player exists in the database
    case existing(Player)
    
    /// Player no longer exists, but we have its latest value.
    case gone(Player)
    
    /// Player does not exist, and we don't have any information about it.
    case missing
    
    var player: Player? {
        switch self {
        case let .existing(player), let .gone(player):
            return player
        case .missing:
            return nil
        }
    }
    
    var exists: Bool {
        switch self {
        case .existing:
            return true
        case .gone, .missing:
            return false
        }
    }
}
