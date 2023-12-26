struct IndexDefinition {
    let name: String
    let table: String
    let expressions: [SQLExpression]
    let options: IndexOptions
    let condition: SQLExpression?
}

/// Index creation options
public struct IndexOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    /// Only creates the index if it does not already exist.
    public static let ifNotExists = IndexOptions(rawValue: 1 << 0)
    
    /// Creates a unique index.
    public static let unique = IndexOptions(rawValue: 1 << 1)
}

extension Database {
    static func defaultIndexName(on table: String, columns: [String]) -> String {
        "index_\(table)_on_\(columns.joined(separator: "_"))"
    }
}
