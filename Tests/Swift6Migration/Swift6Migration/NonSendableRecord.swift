import GRDB

private final class Player: Codable, Identifiable {
    var id: Int64
    var name: String
    var score: Int
    
    init(id: Int64, name: String, score: Int) {
        self.id = id
        self.name = name
        self.score = score
    }
}

extension Player: FetchableRecord, PersistableRecord { }

#if swift(<6)
private struct PlayerRepository {
    var writer: any DatabaseWriter
    
    func fetch() async throws -> Player? {
        // Type 'Player' does not conform to the 'Sendable' protocol
        try await writer.read { db in
            try Player.fetchOne(db, id: 42)
        }
    }
    
    func insert(_ player: Player) async throws {
        // Capture of 'player' with non-sendable type 'Player' in a `@Sendable` closure
        try await writer.read { db in
            try player.insert(db)
        }
    }
    
    func observe() {
        // Type 'Player' does not conform to the 'Sendable' protocol
        let observation = ValueObservation.tracking { db in
            try Player.fetchAll(db)
        }
        _ = observation
    }
}
#endif
