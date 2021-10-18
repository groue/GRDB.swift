import Combine
import GRDB

/// A player request can be used with the `@Query` property wrapper in order to
/// feed a view with a list of players.
///
/// For example:
///
///     struct MyView: View {
///         @Query(PlayerRequest(ordering: .byName)) private var players: [Player]
///
///         var body: some View {
///             List(players) { player in ... )
///         }
///     }
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
            .publisher(
                in: appDatabase.databaseReader,
                scheduling: .immediate) // Feed the view without delay
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
