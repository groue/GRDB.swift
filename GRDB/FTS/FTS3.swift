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
    /// See <https://www.sqlite.org/fts3.html>
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
        #elseif !GRDBCIPHER
        /// Remove diacritics from Latin script characters. This
        /// option matches the raw "remove_diacritics=2" tokenizer argument,
        /// available from SQLite 3.27.0
        @available(OSX 10.16, iOS 14, tvOS 14, watchOS 7, *)
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
    public init() { }
    
    /// Returns an array of tokens found in the string argument.
    ///
    /// For example:
    ///
    ///     FTS3.tokenize("SQLite database")  // ["sqlite", "database"]
    ///     FTS3.tokenize("Gustave Doré")     // ["gustave", "doré"])
    ///
    /// Results can be altered with an explicit tokenizer - default is `.simple`.
    /// See <https://www.sqlite.org/fts3.html#tokenizer>.
    ///
    ///     FTS3.tokenize("SQLite database", withTokenizer: .porter)   // ["sqlite", "databas"]
    ///     FTS3.tokenize("Gustave Doré", withTokenizer: .unicode61()) // ["gustave", "dore"])
    ///
    /// Tokenization is performed by the `fts3tokenize` virtual table described
    /// at <https://www.sqlite.org/fts3.html#querying_tokenizers>.
    public static func tokenize(
        _ string: String,
        withTokenizer tokenizer: FTS3TokenizerDescriptor = .simple)
    -> [String]
    {
        DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(tokenizer.name)
            for option in tokenizer.arguments {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            // Assume fts3tokenize virtual table in an in-memory database always succeeds
            try! db.execute(sql: "CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return try! String.fetchAll(db, sql: """
                SELECT token FROM tokens WHERE input = ? ORDER BY position
                """, arguments: [string])
        }
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts3"
    
    // TODO: remove when `makeTableDefinition()` is no longer a requirement
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func makeTableDefinition() -> FTS3TableDefinition {
        preconditionFailure()
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func makeTableDefinition(configuration: VirtualTableConfiguration) -> FTS3TableDefinition {
        FTS3TableDefinition()
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
    /// See <https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables>
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
