import GRDB

/// The Player struct.
///
/// Identifiable conformance supports type-safe GRDB primary key methods.
/// Hashable conformance supports table view updates
struct Player: Identifiable, Hashable {
    /// The player id.
    ///
    /// Int64 is the recommended type for auto-incremented database ids.
    /// Use nil for players that are not inserted yet in the database.
    var id: Int64?
    var name: String
    var score: Int
}

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
    
    /// Creates a new player with empty name and zero score
    static func new() -> Player {
        Player(id: nil, name: "", score: 0)
    }
    
    /// Creates a new player with random name and random score
    static func newRandom() -> Player {
        Player(id: nil, name: randomName(), score: randomScore())
    }
    
    /// Returns a random name
    static func randomName() -> String {
        names.randomElement()!
    }
    
    /// Returns a random score
    static func randomScore() -> Int {
        10 * Int.random(in: 0...100)
    }
}

// MARK: - Persistence

/// Make Player a Codable Record.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#records>
extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    fileprivate enum Columns {
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    /// Updates a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// MARK: - Player Database Requests

/// Define some player requests used by the application.
///
/// See <https://github.com/groue/GRDB.swift/blob/master/README.md#requests>
/// See <https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md>
extension DerivableRequest where RowDecoder == Player {
    /// A request of players ordered by name.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.all().orderedByName().fetchAll(db)
    ///     }
    func orderedByName() -> Self {
        // Sort by name in a localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#string-comparison
        order(Player.Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
    
    /// A request of players ordered by score.
    ///
    /// For example:
    ///
    ///     let players: [Player] = try dbWriter.read { db in
    ///         try Player.all().orderedByScore().fetchAll(db)
    ///     }
    ///     let bestPlayer: Player? = try dbWriter.read { db in
    ///         try Player.all().orderedByScore().fetchOne(db)
    ///     }
    func orderedByScore() -> Self {
        // Sort by descending score, and then by name, in a
        // localized case insensitive fashion
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#string-comparison
        order(
            Player.Columns.score.desc,
            Player.Columns.name.collating(.localizedCaseInsensitiveCompare))
    }
}
