import GRDB

// A plain Player struct
struct Player {
    // Prefer Int64 for auto-incremented database ids
    var id: Int64?
    var name: String
    var score: Int
}

// Hashable conformance supports tableView diffing
extension Player: Hashable { }

// MARK: - Persistence

// Turn Player into a Codable Record.
// See https://github.com/groue/GRDB.swift/blob/master/README.md#records
extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    private enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// MARK: - Database access

// Define some useful player requests.
// See https://github.com/groue/GRDB.swift/blob/master/README.md#requests
extension Player {
    static func orderedByName() -> QueryInterfaceRequest<Player> {
        return Player.order(Columns.name)
    }
    
    static func orderedByScore() -> QueryInterfaceRequest<Player> {
        return Player.order(Columns.score.desc, Columns.name)
    }
}

// MARK: - Player Randomization

extension Player {
    private static let names = [
        "Arthur", "Anita", "Barbara", "Bernard", "Craig", "Chiara", "David",
        "Dean", "Éric", "Elena", "Fatima", "Frederik", "Gilbert", "Georgette",
        "Henriette", "Hassan", "Ignacio", "Irene", "Julie", "Jack", "Karl",
        "Kristel", "Louis", "Liz", "Masashi", "Mary", "Noam", "Nicole",
        "Ophelie", "Oleg", "Pascal", "Patricia", "Quentin", "Quinn", "Raoul",
        "Rachel", "Stephan", "Susie", "Tristan", "Tatiana", "Ursule", "Urbain",
        "Victor", "Violette", "Wilfried", "Wilhelmina", "Yvon", "Yann",
        "Zazie", "Zoé"]
    
    static func randomName() -> String {
        return names.randomElement()!
    }
    
    static func randomScore() -> Int {
        return 10 * Int.random(in: 0...100)
    }
}
