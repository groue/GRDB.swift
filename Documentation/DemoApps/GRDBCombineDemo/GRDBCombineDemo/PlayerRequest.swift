import Combine
import GRDB

/// A player request defines how to feed the player list.
///
/// It can be used with the `@Query` property wrapper.
struct PlayerRequest: Queryable {
    enum Ordering {
        case byScore
        case byName
    }
    
    var ordering: Ordering
    
    // MARK: - Queryable
    
    static var defaultValue: [Player] { [] }
    
    func valuePublisher(in appDatabase: AppDatabase) -> AnyPublisher<[Player], Error> {
        // Build the publisher from the general-purpose read-only access
        // granted by `appDatabase.databaseReader`.
        // Some apps will prefer to call a dedicated method of `appDatabase`.
        ValueObservation
            .trackingConstantRegion(fetchValue(_:))
            .publisher(in: appDatabase.databaseReader, scheduling: .immediate)
            .eraseToAnyPublisher()
    }
    
    // This method is not required by Queryable, but it makes it easier
    // to test PlayerRequest.
    func fetchValue(_ db: Database) throws -> [Player] {
        switch ordering {
        case .byScore:
            return try Player.all().orderedByScore().fetchAll(db)
        case .byName:
            return try Player.all().orderedByName().fetchAll(db)
        }
    }
}
