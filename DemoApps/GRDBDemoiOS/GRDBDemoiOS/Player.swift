import GRDB

struct Player {
    var id: Int64? // Auto-incremented database ids are Int64
    var name: String
    var score: Int
}

// MARK: - Persistence

extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    // Add ColumnExpression to Codable's CodingKeys so that we can use them
    // as database columns.
    //
    // See https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
    // for more information about CodingKeys.
    private enum CodingKeys: String, CodingKey, ColumnExpression {
        case id, name, score
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// MARK: - Database access

extension Player {
    static func orderedByName() -> QueryInterfaceRequest<Player> {
        return order(CodingKeys.name)
    }
    
    static func orderedByScore() -> QueryInterfaceRequest<Player> {
        return order(CodingKeys.score.desc, CodingKeys.name)
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
