import Combine
import Foundation

/// The view model that validates and saves an edited player into the database.
///
/// It feeds `PlayerForm`, `PlayerCreationSheet` and `PlayerEditionView`.
final class PlayerFormViewModel: ObservableObject {
    /// A validation error that prevents the player from being saved into
    /// the database.
    enum ValidationError: LocalizedError {
        case missingName
        
        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Please give a name to this player."
            }
        }
    }
    
    @Published var name: String = ""
    @Published var score: String = ""
    
    private let database: AppDatabase
    private var player: Player
    
    init(database: AppDatabase, player: Player) {
        self.database = database
        self.player = player
        updateViewFromPlayer()
    }
    
    // MARK: - Manage the Player Form
    
    /// Validates and saves the player into the database.
    func savePlayer() throws {
        if name.isEmpty {
            throw ValidationError.missingName
        }
        player.name = name
        player.score = Int(score) ?? 0
        try database.savePlayer(&player)
    }
    
    /// Resets form values to the original player values.
    func reset() {
        updateViewFromPlayer()
    }
    
    /// Edits a new player
    func editNewPlayer() {
        player = .new()
        updateViewFromPlayer()
    }
    
    // MARK: - Private
    
    private func updateViewFromPlayer() {
        self.name = player.name
        if player.score == 0 && player.id == nil {
            // Avoid displaying "0" for a new player: it does not look good.
            self.score = ""
        } else {
            self.score = "\(player.score)"
        }
    }
}
