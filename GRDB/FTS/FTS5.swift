#if SQLITE_ENABLE_FTS5
// Import C SQLite functions
#if SWIFT_PACKAGE
import GRDBSQLite
#elseif GRDBCIPHER
import SQLCipher
#elseif !GRDBCUSTOMSQLITE && !GRDBCIPHER
import SQLite3
#endif

import Foundation

/// The virtual table module for the FTS5 full-text engine.
///
/// To create FTS5 tables, use the ``Database`` method
/// ``Database/create(virtualTable:options:using:_:)``:
///
/// ```swift
/// // CREATE VIRTUAL TABLE document USING fts5(content)
/// try db.create(virtualTable: "document", using: FTS5()) { t in
///     t.column("content")
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts5.html>
///
/// ## Topics
///
/// ### The FTS5 Module
///
/// - ``init()``
/// - ``FTS5TableDefinition``
/// - ``FTS5ColumnDefinition``
/// - ``FTS5TokenizerDescriptor``
///
/// ### Full-Text Search Pattern
///
/// - ``FTS5Pattern``
///
/// ### FTS5 Tokenizers
///
/// - ``FTS5Tokenizer``
/// - ``FTS5CustomTokenizer``
/// - ``FTS5WrapperTokenizer``
/// - ``FTS5TokenFlags``
/// - ``FTS5Tokenization``
///
/// ### Low-Level FTS5 Customization
///
/// - ``api(_:)``
public struct FTS5 {
    /// Options for Latin script characters. Matches the raw "remove_diacritics"
    /// tokenizer argument.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#unicode61_tokenizer>
    public enum Diacritics: Sendable {
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
        @available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.27+
        case remove
        #endif
    }
    
    /// Creates an FTS5 module.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts5(content)
    /// try db.create(virtualTable: "document", using: FTS5()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// See ``Database/create(virtualTable:options:using:_:)``
    public init() { }
    
    // Support for FTS5Pattern initializers. Don't make public. Users tokenize
    // with `FTS5Tokenizer.tokenize()` methods, which support custom tokenizers,
    // token flags, and query/document tokenzation.
    /// Tokenizes the string argument as an FTS5 query.
    ///
    /// For example:
    ///
    ///     try FTS5.tokenize(query: "SQLite database")  // ["sqlite", "database"]
    ///     try FTS5.tokenize(query: "Gustave Doré")     // ["gustave", "doré"])
    ///
    /// Synonym (colocated) tokens are not present in the returned array. See
    /// `FTS5_TOKEN_COLOCATED` at <https://www.sqlite.org/fts5.html#custom_tokenizers>
    /// for more information.
    ///
    /// - parameter string: The tokenized string.
    /// - returns: An array of tokens.
    /// - throws: An error if tokenization fails.
    static func tokenize(query string: String) throws -> [String] {
        try DatabaseQueue().inDatabase { db in
            try db.makeTokenizer(.ascii()).tokenize(query: string).compactMap {
                $0.flags.contains(.colocated) ? nil : $0.token
            }
        }
    }
    
    /// Returns a pointer to the `fts5_api` structure.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#extending_fts5>
    public static func api(_ db: Database) -> UnsafePointer<fts5_api> {
        var statement: SQLiteStatement? = nil
        var api: UnsafePointer<fts5_api>? = nil
        let type: StaticString = "fts5_api_ptr"
        
        let code = sqlite3_prepare_v3(db.sqliteConnection, "SELECT fts5(?)", -1, 0, &statement, nil)
        guard code == SQLITE_OK else {
            fatalError("FTS5 is not available")
        }
        defer { sqlite3_finalize(statement) }
        type.utf8Start.withMemoryRebound(to: CChar.self, capacity: type.utf8CodeUnitCount) { typePointer in
            _ = sqlite3_bind_pointer(statement, 1, &api, typePointer, nil)
        }
        sqlite3_step(statement)
        guard let api else {
            fatalError("FTS5 is not available")
        }
        return api
    }
}

extension FTS5: VirtualTableModule {
    /// The virtual table module name
    public var moduleName: String { "fts5" }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:options:using:_:)
    public func makeTableDefinition(configuration: VirtualTableConfiguration) -> FTS5TableDefinition {
        FTS5TableDefinition(configuration: configuration)
    }
    
    /// Don't use this method.
    public func moduleArguments(for definition: FTS5TableDefinition, in db: Database) throws -> [String] {
        var arguments: [String] = []
        
        if definition.columns.isEmpty {
            // Programmer error
            fatalError("FTS5 virtual table requires at least one column.")
        }
        
        for column in definition.columns {
            if column.isIndexed {
                arguments.append("\(column.name)")
            } else {
                arguments.append("\(column.name) UNINDEXED")
            }
        }
        
        if let tokenizer = definition.tokenizer {
            let tokenizerSQL = try tokenizer
                .components
                .map { component in
                    try component.sqlExpression.quotedSQL(db)
                }
                .joined(separator: " ")
                .sqlExpression
                .quotedSQL(db)
            arguments.append("tokenize=\(tokenizerSQL)")
        }
        
        switch definition.contentMode {
        case let .raw(content, contentRowID):
            if let content {
                let quotedContent = try content.sqlExpression.quotedSQL(db)
                arguments.append("content=\(quotedContent)")
            }
            if let contentRowID {
                let quotedContentRowID = try contentRowID.sqlExpression.quotedSQL(db)
                arguments.append("content_rowid=\(quotedContentRowID)")
            }
        case let .synchronized(contentTable):
            try arguments.append("content=\(contentTable.sqlExpression.quotedSQL(db))")
            if let rowIDColumn = try db.primaryKey(contentTable).rowIDColumn {
                let quotedRowID = try rowIDColumn.sqlExpression.quotedSQL(db)
                arguments.append("content_rowid=\(quotedRowID)")
            }
        }
        
        
        if let prefixes = definition.prefixes {
            let prefix = try prefixes
                .sorted()
                .map { "\($0)" }
                .joined(separator: " ")
                .sqlExpression
                .quotedSQL(db)
            arguments.append("prefix=\(prefix)")
        }
        
        if let columnSize = definition.columnSize {
            arguments.append("columnSize=\(columnSize)")
        }
        
        if let detail = definition.detail {
            arguments.append("detail=\(detail)")
        }
        
        return arguments
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:options:using:_:)
    public func database(_ db: Database, didCreate tableName: String, using definition: FTS5TableDefinition) throws {
        switch definition.contentMode {
        case .raw:
            break
        case .synchronized(let contentTable):
            // https://sqlite.org/fts5.html#external_content_tables
            
            if definition.configuration.temporary {
                // SQLite can't rebuild the index of temporary tables:
                //
                // sqlite> CREATE TABLE t(id INTEGER PRIMARY KEY, a, b, c);
                // sqlite> CREATE VIRTUAL TABLE temp.ft USING fts5(content="t",content_rowid="a",b,c);
                // sqlite> INSERT INTO ft(ft) VALUES('rebuild');
                // Runtime error: SQL logic error
                fatalError("Temporary external content FTS5 tables are not supported.")
            }
            
            let rowIDColumn = try db.primaryKey(contentTable).rowIDColumn ?? Column.rowID.name
            let ftsTable = tableName.quotedDatabaseIdentifier
            let content = contentTable.quotedDatabaseIdentifier
            let indexedColumns = definition.columns.map(\.name)
            
            let ftsColumns = (["rowid"] + indexedColumns)
                .map(\.quotedDatabaseIdentifier)
                .joined(separator: ", ")
            
            let newContentColumns = ([rowIDColumn] + indexedColumns)
                .map { "new.\($0.quotedDatabaseIdentifier)" }
                .joined(separator: ", ")
            
            let oldContentColumns = ([rowIDColumn] + indexedColumns)
                .map { "old.\($0.quotedDatabaseIdentifier)" }
                .joined(separator: ", ")
            
            let ifNotExists = definition.configuration.ifNotExists
                ? "IF NOT EXISTS "
                : ""
            
            // swiftlint:disable line_length
            try db.execute(sql: """
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_ai".quotedDatabaseIdentifier) AFTER INSERT ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES (\(newContentColumns));
                END;
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_ad".quotedDatabaseIdentifier) AFTER DELETE ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsTable), \(ftsColumns)) VALUES('delete', \(oldContentColumns));
                END;
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_au".quotedDatabaseIdentifier) AFTER UPDATE ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsTable), \(ftsColumns)) VALUES('delete', \(oldContentColumns));
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES (\(newContentColumns));
                END;
                """)
            // swiftlint:enable line_length
            
            // https://sqlite.org/fts5.html#the_rebuild_command
            
            try db.execute(sql: "INSERT INTO \(ftsTable)(\(ftsTable)) VALUES('rebuild')")
        }
    }
}

/// A `FTS5TableDefinition` lets you define the components of an FTS5
/// virtual table.
///
/// You don't create instances of this class. Instead, you use the `Database`
/// ``Database/create(virtualTable:options:using:_:)`` method:
///
/// ```swift
/// try db.create(virtualTable: "document", using: FTS5()) { t in // t is FTS5TableDefinition
///     t.column("content")
/// }
/// ```
///
/// ## Topics
///
/// ### Define Columns
///
/// - ``column(_:)``
///
/// ### External Content Tables
///
/// - ``synchronize(withTable:)``
///
/// ### FTS5 Options
///
/// - ``columnSize``
/// - ``content``
/// - ``contentRowID``
/// - ``detail``
/// - ``prefixes``
/// - ``tokenizer``
public final class FTS5TableDefinition {
    enum ContentMode {
        case raw(content: String?, contentRowID: String?)
        case synchronized(contentTable: String)
    }
    
    fileprivate let configuration: VirtualTableConfiguration
    fileprivate var columns: [FTS5ColumnDefinition] = []
    fileprivate var contentMode: ContentMode = .raw(content: nil, contentRowID: nil)
    
    /// The virtual table tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE "documents" USING fts5(tokenize=porter)
    /// try db.create(virtualTable: "document", using: FTS5()) { t in
    ///     t.tokenizer = .porter()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization>
    public var tokenizer: FTS5TokenizerDescriptor?
    
    /// The FTS5 `content` option.
    ///
    /// When you want the full-text table to be synchronized with the
    /// content of an external table, prefer the
    /// ``synchronize(withTable:)`` method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the ``synchronize(withTable:)`` method.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#external_content_and_contentless_tables>
    public var content: String? {
        get {
            switch contentMode {
            case .raw(let content, _):
                return content
            case .synchronized(let contentTable):
                return contentTable
            }
        }
        set {
            switch contentMode {
            case .raw(_, let contentRowID):
                contentMode = .raw(content: newValue, contentRowID: contentRowID)
            case .synchronized:
                contentMode = .raw(content: newValue, contentRowID: nil)
            }
        }
    }
    
    /// The FTS5 `content_rowid` option
    ///
    /// When you want the full-text table to be synchronized with the
    /// content of an external table, prefer the
    /// ``synchronize(withTable:)`` method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the ``synchronize(withTable:)`` method.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#external_content_tables>
    public var contentRowID: String? {
        get {
            switch contentMode {
            case .raw(_, let contentRowID):
                return contentRowID
            case .synchronized:
                return nil
            }
        }
        set {
            switch contentMode {
            case .raw(let content, _):
                contentMode = .raw(content: content, contentRowID: newValue)
            case .synchronized:
                contentMode = .raw(content: nil, contentRowID: newValue)
            }
        }
    }
    
    /// The FTS5 `prefix` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#prefix_indexes>
    public var prefixes: Set<Int>?
    
    /// The FTS5 `columnsize` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#the_columnsize_option>
    public var columnSize: Int?
    
    /// The FTS5 `detail` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#the_detail_option>
    public var detail: String?
    
    init(configuration: VirtualTableConfiguration) {
        self.configuration = configuration
    }
    
    /// Appends a table column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts5(content)
    /// try db.create(virtualTable: "document", using: FTS5()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// - parameter name: the column name.
    /// - returns: A ``FTS5ColumnDefinition`` that allows you to refine the
    ///   column definition.
    @discardableResult
    public func column(_ name: String) -> FTS5ColumnDefinition {
        let column = FTS5ColumnDefinition(name: name)
        columns.append(column)
        return column
    }
    
    /// Synchronizes the full-text table with the content of an external
    /// table.
    ///
    /// The full-text table is initially populated with the existing
    /// content in the external table. SQL triggers make sure that the
    /// full-text table is kept up to date with the external table.
    ///
    /// SQLite automatically deletes those triggers when the content
    /// (not full-text) table is dropped.
    ///
    /// However, those triggers remain after the full-text table has been
    /// dropped. Unless they are dropped too, they will prevent future
    /// insertion, updates, and deletions in the content table, and the creation
    /// of a new full-text table.
    ///
    /// To drop those triggers, call the `Database`
    /// ``Database/dropFTS5SynchronizationTriggers(forTable:)`` method:
    ///
    /// ```swift
    /// // Create tables
    /// try db.create(table: "book") { t in
    ///     ...
    /// }
    /// try db.create(virtualTable: "book_ft", using: FTS5()) { t in
    ///     t.synchronize(withTable: "book")
    ///     ...
    /// }
    ///
    /// // Drop full-text table
    /// try db.drop(table: "book_ft")
    /// try db.dropFTS5SynchronizationTriggers(forTable: "book_ft")
    /// ```
    ///
    /// Related SQLite documentation: <https://sqlite.org/fts5.html#external_content_tables>
    public func synchronize(withTable tableName: String) {
        contentMode = .synchronized(contentTable: tableName)
    }
}

// Explicit non-conformance to Sendable: `FTS5TableDefinition` is a mutable
// class and there is no known reason for making it thread-safe.
@available(*, unavailable)
extension FTS5TableDefinition: Sendable { }

/// Describes a column in an ``FTS5`` virtual table.
///
/// You get instances of `FTS5ColumnDefinition` when you create an ``FTS5``
/// virtual table. For example:
///
/// ```swift
/// try db.create(virtualTable: "document", using: FTS5()) { t in
///     t.column("content")      // FTS5ColumnDefinition
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts5.html>
public final class FTS5ColumnDefinition {
    fileprivate let name: String
    fileprivate var isIndexed: Bool
    
    init(name: String) {
        self.name = name
        self.isIndexed = true
    }
    
    /// Excludes the column from the full-text index.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "document", using: FTS5()) { t in
    ///     t.column("a")
    ///     t.column("b").notIndexed()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts5.html#the_unindexed_column_option>
    ///
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func notIndexed() -> Self {
        self.isIndexed = false
        return self
    }
}

// Explicit non-conformance to Sendable: `FTS5ColumnDefinition` is a mutable
// class and there is no known reason for making it thread-safe.
@available(*, unavailable)
extension FTS5ColumnDefinition: Sendable { }

extension Column {
    /// The ``FTS5`` rank column.
    public static let rank = Column("rank")
}

extension Database {
    /// Deletes the synchronization triggers for a synchronized FTS5 table.
    public func dropFTS5SynchronizationTriggers(forTable tableName: String) throws {
        try execute(sql: """
            DROP TRIGGER IF EXISTS \("__\(tableName)_ai".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_ad".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_au".quotedDatabaseIdentifier);
            """)
    }
}
#endif
