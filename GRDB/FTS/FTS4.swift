/// FTS4 lets you define "fts4" virtual tables.
///
///     // CREATE VIRTUAL TABLE documents USING fts4(content)
///     try db.create(virtualTable: "documents", using: FTS4()) { t in
///         t.column("content")
///     }
public struct FTS4 : VirtualTableModule {
    
    /// TODO
    public enum Storage {
        case regular
        case contentless
        case externalContent(String)
    }
    
    let storage: Storage

    /// Creates a FTS4 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts4(content)
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// For contentless FTS4 table, and external content FTS4 table, provide a
    /// storage argument:
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts4(content="", title, body)
    ///     let fts4 = FTS4(storage: .contentless)
    ///     try db.create(virtualTable: "documents", using: fts4) { t in
    ///         t.column("title")
    ///         t.column("body")
    ///     }
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts4(content="source", title, body)
    ///     // let fts4 = FTS4(storage: .externalContent("source"))
    ///     try db.create(virtualTable: "documents", using: fts4) { t in
    ///         t.column("title")
    ///         t.column("body")
    ///     }
    public init(storage: Storage = .regular) {
        self.storage = storage
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
    
    /// TODO
    public var compress: String?
    
    /// TODO
    public var uncompress: String?
    
    /// TODO
    public var languageid
    
    /// TODO (as a column property)
    public var notindexed
    
    /// TODO
    public var prefix
    
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
