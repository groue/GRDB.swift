import GRDB

struct Player: Codable, Identifiable {
    var id: Int64?
    var name: String
    var score: Int
    var photoID: Int
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
    
    /// Creates a new player with random name and random score
    static func makeRandom(id: ID = nil) -> Player {
        Player(
            id: id,
            name: names.randomElement()!,
            score: 10 * Int.random(in: 0...100),
            photoID: Int.random(in: 0...1000))
    }
    
    /// A placeholder Player
    static let placeholder = Player(name: "xxxxxx", score: 100, photoID: 1)
}

extension Player: FetchableRecord, MutablePersistableRecord {
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}
