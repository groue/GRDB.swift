/// FTS4 lets you define "fts4" virtual tables.
///
///     try db.create(virtualTable: "documents", using: FTS4()) { t in
///         t.column("content")
///     }
public struct FTS4 : VirtualTableModule {
    /// Creates a FTS4 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    public init() {
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts4"
    
    /// Don't use this method.
    public func makeTableDefinition() -> FTS4TableDefinition {
        return FTS4TableDefinition()
    }
    
    /// Don't use this method.
    public func moduleArguments(_ definition: FTS4TableDefinition) -> [String] {
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

/// The FTS4TableDefinition class lets you define columns of a FTS4 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "documents", using: FTS4()) { t in // t is FTS4TableDefinition
///         t.column("content")
///     }
public final class FTS4TableDefinition : VirtualTableDefinition {
    fileprivate var columns: [String] = []
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.tokenizer = .porter
    ///     }
    public var tokenizer: FTS3Tokenizer?
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
    public func column(_ name: String) {
        columns.append(name)
    }
}
