import Foundation
import Observation
import GRDB

@Observable @MainActor final class PlayerListModel {
    /// A player ordering
    enum Ordering {
        case byName
        case byScore
    }
    
    /// The player ordering
    var ordering = Ordering.byScore {
        didSet { observePlayers() }
    }
    
    /// The players.
    ///
    /// The array remains empty until `observePlayers()` is called.
    var players: [Player] = []
    
    private let appDatabase: AppDatabase
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
    
    /// Creates a `PlayerListModel`.
    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }
    
    /// Start observing the database.
    func observePlayers() {
        let observation = ValueObservation.tracking { [ordering] db in
            switch ordering {
            case .byName:
                try Player.all().orderedByName().fetchAll(db)
            case .byScore:
                try Player.all().orderedByScore().fetchAll(db)
            }
        }
        
        cancellable = observation.start(in: appDatabase.reader) { error in
            // Handle error
        } onChange: { [unowned self] players in
            self.players = players
        }
    }
    
    func deletePlayers(at offsets: IndexSet) throws {
        let playerIds = offsets.compactMap { players[$0].id }
        try appDatabase.deletePlayers(ids: playerIds)
    }
    
    func deleteAllPlayers() throws {
        try appDatabase.deleteAllPlayers()
    }
    
    func refreshPlayers() async throws  {
        try await appDatabase.refreshPlayers()
    }
    
    func refreshPlayersManyTimes() async throws {
        // Perform 50 refreshes in parallel
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    try await AppDatabase.shared.refreshPlayers()
                }
            }
            for try await _ in group { }
        }
    }
}
