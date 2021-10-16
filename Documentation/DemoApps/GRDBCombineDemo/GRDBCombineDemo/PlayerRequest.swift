import Combine
import GRDB

/// A player request defines how to feed the player list
struct PlayerRequest {
    enum Ordering {
        case byScore
        case byName
    }
    
    var ordering: Ordering
}

/// Make `PlayerRequest` able to be used with the `@Query` property wrapper.
extension PlayerRequest: Queryable {
    static var defaultValue: [Player] { [] }
    
    func valuePublisher(in appDatabase: AppDatabase) -> AnyPublisher<[Player], Error> {
        ValueObservation
            .trackingConstantRegion { db in
                switch ordering {
                case .byScore:
                    return try Player.all().orderedByScore().fetchAll(db)
                case .byName:
                    return try Player.all().orderedByName().fetchAll(db)
                }
            }
            .publisher(in: appDatabase.databaseReader, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
}
