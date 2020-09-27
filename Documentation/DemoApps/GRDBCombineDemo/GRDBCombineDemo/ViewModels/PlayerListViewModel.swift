import Combine
import Foundation

/// The view model that feeds `PlayerList`, and performs list modifications
/// in the database.
final class PlayerListViewModel: ObservableObject {
    enum Ordering {
        case byScore
        case byName
    }
    
    struct PlayerList {
        var players: [Player]
        var animatedChanges: Bool
    }
    
    /// The list ordering
    @Published var ordering: Ordering = .byScore
    
    /// The players in the list
    @Published var playerList = PlayerList(players: [], animatedChanges: false)
    
    /// The view model that edits a new player
    let newPlayerViewModel: PlayerFormViewModel
    
    private let database: AppDatabase
    private var playersCancellable: AnyCancellable?
    
    init(database: AppDatabase) {
        self.database = database
        newPlayerViewModel = PlayerFormViewModel(database: database, player: .new())
        playersCancellable = playersPublisher(in: database)
            .scan(nil) { (previousList: PlayerList?, players: [Player]) in
                if previousList == nil {
                    // Do not animate first view update
                    return PlayerList(players: players, animatedChanges: false)
                } else {
                    return PlayerList(players: players, animatedChanges: true)
                }
            }
            .compactMap { $0 }
            .sink { [weak self] playerList in
                self?.playerList = playerList
            }
    }
    
    // MARK: - Players List Management
    
    /// Deletes all players
    func deleteAllPlayers() {
        // Eventual error presentation is left as an exercise for the reader.
        try! database.deleteAllPlayers()
    }
    
    func deletePlayers(atOffsets offsets: IndexSet) {
        // Eventual error presentation is left as an exercise for the reader.
        let playerIDs = offsets.compactMap { playerList.players[$0].id }
        try! database.deletePlayers(ids: playerIDs)
    }
    
    /// Refreshes the list of players
    func refreshPlayers() {
        // Eventual error presentation is left as an exercise for the reader.
        try! database.refreshPlayers()
    }
    
    /// Spawns many concurrent database updates, for demo purpose
    func stressTest() {
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refreshPlayers()
            }
        }
    }
    
    // MARK: - Change Player Ordering
    
    /// Toggles between the available orderings
    func toggleOrdering() {
        switch ordering {
        case .byName:
            ordering = .byScore
        case .byScore:
            ordering = .byName
        }
    }
    
    // MARK: - Player Edition
    
    /// Returns a view model suitable for editing a player.
    func formViewModel(for player: Player) -> PlayerFormViewModel {
        PlayerFormViewModel(database: database, player: player)
    }
    
    // MARK: - Private
    
    /// Returns a publisher of the players in the list
    private func playersPublisher(in database: AppDatabase) -> AnyPublisher<[Player], Never> {
        // Players depend on the current ordering
        $ordering.map { ordering -> AnyPublisher<[Player], Error> in
            switch ordering {
            case .byScore:
                return database.playersOrderedByScorePublisher()
            case .byName:
                return database.playersOrderedByNamePublisher()
            }
        }
        .map { playersPublisher in
            // Turn database errors into an empty players list.
            // Eventual error presentation is left as an exercise for the reader.
            playersPublisher.catch { error in
                Just<[Player]>([])
            }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }
}
