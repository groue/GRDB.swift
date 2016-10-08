/// FTS3 lets you define "fts3" virtual tables.
///
///     // CREATE VIRTUAL TABLE documents USING fts3(content)
///     try db.create(virtualTable: "documents", using: FTS3()) { t in
///         t.column("content")
///     }
public struct FTS3 : VirtualTableModule {
    /// Creates a FTS3 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts3(content)
    ///     try db.create(virtualTable: "documents", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    public init() {
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts3"
    
    /// Don't use this method.
    public func makeTableDefinition() -> FTS3TableDefinition {
        return FTS3TableDefinition()
    }
    
    /// Don't use this method.
    public func moduleArguments(_ definition: FTS3TableDefinition) -> [String] {
        var arguments = definition.columns
        if let tokenizer = definition.tokenizer {
            if tokenizer.options.isEmpty {
                arguments.append("tokenize=\(tokenizer.name)")
            } else {
                arguments.append("tokenize=\(tokenizer.name) " + tokenizer.options.map { "\"\($0)\"" as String }.joined(separator: " "))
            }
        }
        return arguments
    }
}

/// The FTS3TableDefinition class lets you define columns of a FTS3 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "documents", using: FTS3()) { t in // t is FTS3TableDefinition
///         t.column("content")
///     }
public final class FTS3TableDefinition {
    fileprivate var columns: [String] = []
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "documents", using: FTS3()) { t in
    ///         t.tokenizer = .porter
    ///     }
    /// See https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables
    public var tokenizer: FTS3Tokenizer?
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
    public func column(_ name: String) {
        columns.append(name)
    }
}
