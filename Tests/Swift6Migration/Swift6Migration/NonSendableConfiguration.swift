import GRDB

private struct Player1: Codable { }
private struct Player2: Codable { }

#if swift(<6)
extension Player1: FetchableRecord, MutablePersistableRecord {
    // Static property 'databaseSelection' is not concurrency-safe
    // because non-'Sendable' type '[any SQLSelectable]'
    // may have shared mutable state
    static let databaseSelection: [any SQLSelectable] = [
        Column("id"), Column("name"), Column("score")
    ]
}
#endif

extension Player2: FetchableRecord, MutablePersistableRecord {
    static var databaseSelection: [any SQLSelectable] {
        [Column("id"), Column("name"), Column("score")]
    }
}
