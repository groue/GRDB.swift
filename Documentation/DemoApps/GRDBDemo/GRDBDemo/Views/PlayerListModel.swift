import Foundation
import Observation
import GRDB

/// The observable model that drives the main navigation view.
///
/// It observes the database in order to always display an up-to-date list
/// of players.
///
/// This class is testable. See `PlayerListModelTests.swift`.
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
    
    // MARK: - Initialization
    
    /// Creates a `PlayerListModel`.
    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }
    
    /// Start observing the database.
    func observePlayers() {
        // We observe all players, sorted according to `ordering`.
        let observation = ValueObservation.tracking { [ordering] db in
            switch ordering {
            case .byName:
                try Player.all().orderedByName().fetchAll(db)
            case .byScore:
                try Player.all().orderedByScore().fetchAll(db)
            }
        }
        
        // Start observing the database.
        // Previous observation, if any, is cancelled.
        cancellable = observation.start(in: appDatabase.reader) { error in
            // Handle error
        } onChange: { [unowned self] players in
            self.players = players
        }
    }
    
    // MARK: - Actions
    
    /// Delete players at specified indexes in `self.players`.
    func deletePlayers(at offsets: IndexSet) throws {
        let playerIds = offsets.compactMap { players[$0].id }
        try appDatabase.deletePlayers(ids: playerIds)
    }
    
    /// Delete all players.
    func deleteAllPlayers() throws {
        try appDatabase.deleteAllPlayers()
    }
    
    /// Refresh all players (by performing some random changes, for demo purpose).
    func refreshPlayers() async throws  {
        try await appDatabase.refreshPlayers()
    }
    
    /// Perform 50 refreshes in parallel, for demo purpose.
    func refreshPlayersManyTimes() async throws {
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
