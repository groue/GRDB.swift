/// FTS3 lets you define "fts3" virtual tables.
///
///     // CREATE VIRTUAL TABLE document USING fts3(content)
///     try db.create(virtualTable: "document", using: FTS3()) { t in
///         t.column("content")
///     }
public struct FTS3: VirtualTableModule {
    /// Options for Latin script characters. Matches the raw "remove_diacritics"
    /// tokenizer argument.
    ///
    /// See https://www.sqlite.org/fts3.html
    public enum Diacritics {
        /// Do not remove diacritics from Latin script characters. This
        /// option matches the raw "remove_diacritics=0" tokenizer argument.
        case keep
        /// Remove diacritics from Latin script characters. This
        /// option matches the raw "remove_diacritics=1" tokenizer argument.
        case removeLegacy
        #if GRDBCUSTOMSQLITE
        /// Remove diacritics from Latin script characters. This
        /// option matches the raw "remove_diacritics=2" tokenizer argument,
        /// available from SQLite 3.27.0
        case remove
        #endif
    }
    
    /// Creates a FTS3 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE document USING fts3(content)
    ///     try db.create(virtualTable: "document", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    public init() {
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts3"
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func makeTableDefinition() -> FTS3TableDefinition {
        return FTS3TableDefinition()
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func moduleArguments(for definition: FTS3TableDefinition, in db: Database) -> [String] {
        var arguments = definition.columns
        if let tokenizer = definition.tokenizer {
            if tokenizer.arguments.isEmpty {
                arguments.append("tokenize=\(tokenizer.name)")
            } else {
                arguments.append(
                    "tokenize=\(tokenizer.name) " + tokenizer.arguments
                        .map { "\"\($0)\"" as String }
                        .joined(separator: " "))
            }
        }
        return arguments
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func database(_ db: Database, didCreate tableName: String, using definition: FTS3TableDefinition) {
    }
}

/// The FTS3TableDefinition class lets you define columns of a FTS3 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "document", using: FTS3()) { t in // t is FTS3TableDefinition
///         t.column("content")
///     }
public final class FTS3TableDefinition {
    fileprivate var columns: [String] = []
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "document", using: FTS3()) { t in
    ///         t.tokenizer = .porter
    ///     }
    /// See https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables
    public var tokenizer: FTS3TokenizerDescriptor?
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "document", using: FTS3()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
    public func column(_ name: String) {
        columns.append(name)
    }
}
