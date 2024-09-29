import GRDB

private struct Player: Codable, FetchableRecord, PersistableRecord { }
let writer: any DatabaseWriter = { fatalError() }()

private func fetchPlayers() async throws -> [Player] {
    try await writer.read(Player.fetchAll)
}

private func foo() {
    Task {
        let players = try writer.read(Player.fetchAll)
    }
}

private struct PlayerRepository {
    var writer: any DatabaseWriter
    
    func fetchPlayers() throws -> [Player] {
        try writer.read(Player.fetchAll)
    }
}


private func bar() {
    let repository = try! PlayerRepository(writer: DatabaseQueue())
    Task {
        let players = try repository.fetchPlayers()
    }
}
