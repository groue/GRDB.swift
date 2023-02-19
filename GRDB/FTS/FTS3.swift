/// The virtual table module for the FTS3 full-text engine.
///
/// To create FTS3 tables, use the ``Database`` method
/// ``Database/create(virtualTable:ifNotExists:using:_:)``:
///
/// ```swift
/// // CREATE VIRTUAL TABLE document USING fts3(content)
/// try db.create(virtualTable: "document", using: FTS3()) { t in
///     t.column("content")
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts3.html>
///
/// ## Topics
///
/// ### The FTS3 Module
///
/// - ``init()``
/// - ``FTS3TableDefinition``
/// - ``FTS3TokenizerDescriptor``
///
/// ### Full-Text Search Pattern
///
/// - ``FTS3Pattern``
///
/// ### Tokenizing Strings
///
/// - ``tokenize(_:withTokenizer:)``
public struct FTS3 {
    /// Options for Latin script characters.
    public enum Diacritics {
        /// Do not remove diacritics from Latin script characters. This option
        /// matches the `remove_diacritics=0` tokenizer argument.
        ///
        /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#tokenizer>
        case keep
        
        /// Remove diacritics from Latin script characters. This option matches
        /// the `remove_diacritics=1` tokenizer argument.
        case removeLegacy
        
        #if GRDBCUSTOMSQLITE
        /// Remove diacritics from Latin script characters. This option matches
        /// the `remove_diacritics=2` tokenizer argument.
        case remove
        #elseif !GRDBCIPHER
        /// Remove diacritics from Latin script characters. This option matches
        /// the `remove_diacritics=2` tokenizer argument.
        @available(iOS 14, macOS 10.16, tvOS 14, watchOS 7, *) // SQLite 3.27+
        case remove
        #endif
    }
    
    /// Creates an FTS3 module.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts3(content)
    /// try db.create(virtualTable: "document", using: FTS3()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// See ``Database/create(virtualTable:ifNotExists:using:_:)``
    public init() { }
    
    /// Returns an array of tokens found in the string argument.
    ///
    /// For example:
    ///
    /// ```swift
    /// // ["sqlite", "database"]
    /// try FTS3.tokenize("SQLite database")
    ///
    /// // ["gustave", "doré"])
    /// try FTS3.tokenize("Gustave Doré")
    /// ```
    ///
    /// Results can be altered with the `tokenizer` argument:
    ///
    /// ```swift
    /// // ["sqlite", "databas"]
    /// try FTS3.tokenize("SQLite database", withTokenizer: .porter)
    ///
    /// // ["gustave", "dore"])
    /// try FTS3.tokenize("Gustave Doré", withTokenizer: .unicode61())
    /// ```
    ///
    /// Related SQLite documentation:
    ///
    /// - <https://www.sqlite.org/fts3.html#tokenizer>
    /// - <https://www.sqlite.org/fts3.html#querying_tokenizers>
    ///
    /// - throws: A ``DatabaseError`` whenever an SQLite error occurs.
    public static func tokenize(
        _ string: String,
        withTokenizer tokenizer: FTS3TokenizerDescriptor = .simple)
    throws -> [String]
    {
        try DatabaseQueue().inDatabase { db in
            var tokenizerChunks: [String] = []
            tokenizerChunks.append(tokenizer.name)
            for option in tokenizer.arguments {
                tokenizerChunks.append("\"\(option)\"")
            }
            let tokenizerSQL = tokenizerChunks.joined(separator: ", ")
            try db.execute(sql: "CREATE VIRTUAL TABLE tokens USING fts3tokenize(\(tokenizerSQL))")
            return try String.fetchAll(db, sql: """
                SELECT token FROM tokens WHERE input = ? ORDER BY position
                """, arguments: [string])
        }
    }
}

extension FTS3: VirtualTableModule {
    public var moduleName: String { "fts3" }
    
    public func makeTableDefinition(configuration: VirtualTableConfiguration) -> FTS3TableDefinition {
        FTS3TableDefinition()
    }
    
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
    
    public func database(_ db: Database, didCreate tableName: String, using definition: FTS3TableDefinition) { }
}

/// A `FTS3TableDefinition` lets you define the components of an FTS3
/// virtual table.
///
/// You don't create instances of this class. Instead, you use the `Database`
/// ``Database/create(virtualTable:ifNotExists:using:_:)`` method:
///
/// ```swift
/// try db.create(virtualTable: "document", using: FTS3()) { t in // t is FTS3TableDefinition
///     t.column("content")
/// }
/// ```
public final class FTS3TableDefinition {
    fileprivate var columns: [String] = []
    
    /// The virtual table tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE documents USING fts3(tokenize=porter)
    /// try db.create(virtualTable: "document", using: FTS3()) { t in
    ///     t.tokenizer = .porter
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables>
    public var tokenizer: FTS3TokenizerDescriptor?
    
    /// Appends a table column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts3(content)
    /// try db.create(virtualTable: "document", using: FTS3()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// - parameter name: the column name.
    public func column(_ name: String) {
        columns.append(name)
    }
}
