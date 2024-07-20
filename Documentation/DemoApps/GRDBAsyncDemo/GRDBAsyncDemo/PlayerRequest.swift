import GRDB
import GRDBQuery

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
struct PlayerRequest: ValueObservationQueryable {
    enum Ordering {
        case byScore
        case byName
    }
    
    static var defaultValue: [Player] { [] }
    
    /// The ordering used by the player request.
    var ordering: Ordering
    
    func fetch(_ db: Database) throws -> [Player] {
        switch ordering {
        case .byScore:
            return try Player.all().orderedByScore().fetchAll(db)
        case .byName:
            return try Player.all().orderedByName().fetchAll(db)
        }
    }
}
