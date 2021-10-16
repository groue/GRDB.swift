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
    
    func values(in appDatabase: AppDatabase) -> AsyncValueObservation<[Player]> {
        ValueObservation
            .trackingConstantRegion { db in
                switch ordering {
                case .byScore:
                    return try Player.all().orderedByScore().fetchAll(db)
                case .byName:
                    return try Player.all().orderedByName().fetchAll(db)
                }
            }
            .values(in: appDatabase.databaseReader, scheduling: .immediate)
    }
}
