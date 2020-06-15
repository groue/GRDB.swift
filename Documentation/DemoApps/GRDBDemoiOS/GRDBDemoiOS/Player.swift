import GRDB

/// The Player struct
struct Player {
    var id: Int64? // Use Int64 for auto-incremented database ids
    var name: String
    var score: Int
}

/// Hashable conformance supports tableView diffing
extension Player: Hashable { }

// MARK: - Persistence

/// Make Player a Codable Record.
///
/// See https://github.com/groue/GRDB.swift/blob/master/README.md#records
extension Player: Codable, FetchableRecord, MutablePersistableRecord {
    // Define database columns from CodingKeys
    fileprivate enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let score = Column(CodingKeys.score)
    }
    
    // Update a player id after it has been inserted in the database.
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

// MARK: - Player Requests

/// Define some player requests used by the application.
///
/// See https://github.com/groue/GRDB.swift/blob/master/README.md#requests
/// See https://github.com/groue/GRDB.swift/blob/master/Documentation/GoodPracticesForDesigningRecordTypes.md
extension DerivableRequest where RowDecoder == Player {
    /// A request of players ordered by name
    ///
    /// For example:
    ///
    ///     let players = try dbQueue.read { db in
    ///         try Player.all().orderedByName().fetchAll(db)
    ///     }
    func orderedByName() -> Self {
        order(Player.Columns.name)
    }
    
    /// A request of players ordered by score
    ///
    /// For example:
    ///
    ///     let players = try dbQueue.read { db in
    ///         try Player.all().orderedByScore().fetchAll(db)
    ///     }
    func orderedByScore() -> Self {
        order(Player.Columns.score.desc, Player.Columns.name)
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
        names.randomElement()!
    }
    
    static func randomScore() -> Int {
        10 * Int.random(in: 0...100)
    }
}
