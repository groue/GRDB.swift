/// The virtual table module for the FTS4 full-text engine.
///
/// To create FTS4 tables, use the ``Database`` method
/// ``Database/create(virtualTable:ifNotExists:using:_:)``:
///
/// ```swift
/// // CREATE VIRTUAL TABLE document USING fts4(content)
/// try db.create(virtualTable: "document", using: FTS4()) { t in
///     t.column("content")
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts3.html>
///
/// ## Topics
///
/// ### The FTS4 Module
///
/// - ``init()``
/// - ``FTS4TableDefinition``
/// - ``FTS4ColumnDefinition``
public struct FTS4 {
    /// Creates an FTS4 module.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts4(content)
    /// try db.create(virtualTable: "document", using: FTS4()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// See ``Database/create(virtualTable:ifNotExists:using:_:)``
    public init() { }
}

extension FTS4: VirtualTableModule {
    public var moduleName: String { "fts4" }
    
    public func makeTableDefinition(configuration: VirtualTableConfiguration) -> FTS4TableDefinition {
        FTS4TableDefinition(configuration: configuration)
    }
    
    public func moduleArguments(for definition: FTS4TableDefinition, in db: Database) -> [String] {
        var arguments: [String] = []
        
        for column in definition.columns {
            if column.isLanguageId {
                arguments.append("languageid=\"\(column.name)\"")
            } else {
                arguments.append(column.name)
                if !column.isIndexed {
                    arguments.append("notindexed=\(column.name)")
                }
            }
        }
        
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
        
        switch definition.contentMode {
        case .raw(let content):
            if let content {
                arguments.append("content=\"\(content)\"")
            }
        case .synchronized(let contentTable):
            arguments.append("content=\"\(contentTable)\"")
        }
        
        if let compress = definition.compress {
            arguments.append("compress=\"\(compress)\"")
        }
        
        if let uncompress = definition.uncompress {
            arguments.append("uncompress=\"\(uncompress)\"")
        }
        
        if let matchinfo = definition.matchinfo {
            arguments.append("matchinfo=\"\(matchinfo)\"")
        }
        
        if let prefixes = definition.prefixes {
            arguments.append("prefix=\"\(prefixes.sorted().map { "\($0)" }.joined(separator: ","))\"")
        }
        
        return arguments
    }
    
    public func database(_ db: Database, didCreate tableName: String, using definition: FTS4TableDefinition) throws {
        switch definition.contentMode {
        case .raw:
            break
        case .synchronized(let contentTable):
            // https://www.sqlite.org/fts3.html#_external_content_fts4_tables_
            
            let rowIDColumn = try db.primaryKey(contentTable).rowIDColumn ?? Column.rowID.name
            let ftsTable = tableName.quotedDatabaseIdentifier
            let content = contentTable.quotedDatabaseIdentifier
            let indexedColumns = definition.columns.map(\.name)
            
            let ftsColumns = (["docid"] + indexedColumns)
                .map(\.quotedDatabaseIdentifier)
                .joined(separator: ", ")
            
            let newContentColumns = ([rowIDColumn] + indexedColumns)
                .map { "new.\($0.quotedDatabaseIdentifier)" }
                .joined(separator: ", ")
            
            let oldRowID = "old.\(rowIDColumn.quotedDatabaseIdentifier)"
            
            let ifNotExists = definition.configuration.ifNotExists
                ? "IF NOT EXISTS "
                : ""
            
            // swiftlint:disable line_length
            try db.execute(sql: """
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_bu".quotedDatabaseIdentifier) BEFORE UPDATE ON \(content) BEGIN
                    DELETE FROM \(ftsTable) WHERE docid=\(oldRowID);
                END;
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_bd".quotedDatabaseIdentifier) BEFORE DELETE ON \(content) BEGIN
                    DELETE FROM \(ftsTable) WHERE docid=\(oldRowID);
                END;
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_au".quotedDatabaseIdentifier) AFTER UPDATE ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES(\(newContentColumns));
                END;
                CREATE TRIGGER \(ifNotExists)\("__\(tableName)_ai".quotedDatabaseIdentifier) AFTER INSERT ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES(\(newContentColumns));
                END;
                """)
            // swiftlint:enable line_length
            
            // https://www.sqlite.org/fts3.html#*fts4rebuidcmd
            
            try db.execute(sql: "INSERT INTO \(ftsTable)(\(ftsTable)) VALUES('rebuild')")
        }
    }
}

/// A `FTS4TableDefinition` lets you define the components of an FTS4
/// virtual table.
///
/// You don't create instances of this class. Instead, you use the `Database`
/// ``Database/create(virtualTable:ifNotExists:using:_:)`` method:
///
/// ```swift
/// try db.create(virtualTable: "document", using: FTS4()) { t in // t is FTS4TableDefinition
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
/// ### FTS4 Options
///
/// - ``compress``
/// - ``content``
/// - ``matchinfo``
/// - ``prefixes``
/// - ``tokenizer``
/// - ``uncompress``
public final class FTS4TableDefinition {
    enum ContentMode {
        case raw(content: String?)
        case synchronized(contentTable: String)
    }
    
    fileprivate let configuration: VirtualTableConfiguration
    fileprivate var columns: [FTS4ColumnDefinition] = []
    fileprivate var contentMode: ContentMode = .raw(content: nil)
    
    /// The virtual table tokenizer.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE documents USING fts4(tokenize=porter)
    /// try db.create(virtualTable: "document", using: FTS4()) { t in
    ///     t.tokenizer = .porter
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables>
    public var tokenizer: FTS3TokenizerDescriptor?
    
    /// The FTS4 `content` option.
    ///
    /// When you want the full-text table to be synchronized with the
    /// content of an external table, prefer the
    /// ``synchronize(withTable:)`` method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the ``synchronize(withTable:)`` method.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_content_option_>
    public var content: String? {
        get {
            switch contentMode {
            case .raw(let content):
                return content
            case .synchronized(let contentTable):
                return contentTable
            }
        }
        set {
            contentMode = .raw(content: newValue)
        }
    }
    
    /// The FTS4 `compress` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_compress_and_uncompress_options>
    public var compress: String?
    
    /// The FTS4 `uncompress` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_compress_and_uncompress_options>
    public var uncompress: String?
    
    /// The FTS4 `matchinfo` option.
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_matchinfo_option>
    public var matchinfo: String?
    
    /// The FTS4 `prefix` option.
    ///
    ///     // CREATE VIRTUAL TABLE document USING FTS4(content, prefix='2 4');
    ///     try db.create(virtualTable: "document", using:FTS4()) { t in
    ///         t.prefixes = [2, 4]
    ///         t.column("content")
    ///     }
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_prefix_option>
    public var prefixes: Set<Int>?
    
    init(configuration: VirtualTableConfiguration) {
        self.configuration = configuration
    }
    
    /// Appends a table column.
    ///
    /// For example:
    ///
    /// ```swift
    /// // CREATE VIRTUAL TABLE document USING fts4(content)
    /// try db.create(virtualTable: "document", using: FTS4()) { t in
    ///     t.column("content")
    /// }
    /// ```
    ///
    /// - parameter name: the column name.
    /// - returns: A ``FTS4ColumnDefinition`` that allows you to refine the
    ///   column definition.
    @discardableResult
    public func column(_ name: String) -> FTS4ColumnDefinition {
        let column = FTS4ColumnDefinition(name: name)
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
    /// ``Database/dropFTS4SynchronizationTriggers(forTable:)`` method:
    ///
    /// ```swift
    /// // Create tables
    /// try db.create(table: "book") { t in
    ///     ...
    /// }
    /// try db.create(virtualTable: "book_ft", using: FTS4()) { t in
    ///     t.synchronize(withTable: "book")
    ///     ...
    /// }
    ///
    /// // Drop full-text table
    /// try db.drop(table: "book_ft")
    /// try db.dropFTS4SynchronizationTriggers(forTable: "book_ft")
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#_external_content_fts4_tables_>
    public func synchronize(withTable tableName: String) {
        contentMode = .synchronized(contentTable: tableName)
    }
}

/// Describes a column in an ``FTS4`` virtual table.
///
/// You get instances of `FTS4ColumnDefinition` when you create an ``FTS4``
/// virtual table. For example:
///
/// ```swift
/// try db.create(virtualTable: "document", using: FTS4()) { t in
///     t.column("content")      // FTS4ColumnDefinition
/// }
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/fts3.html>
public final class FTS4ColumnDefinition {
    fileprivate let name: String
    fileprivate var isIndexed: Bool
    fileprivate var isLanguageId: Bool
    
    init(name: String) {
        self.name = name
        self.isIndexed = true
        self.isLanguageId = false
    }
    
    /// Excludes the column from the full-text index.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "document", using: FTS4()) { t in
    ///     t.column("a")
    ///     t.column("b").notIndexed()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_notindexed_option>
    ///
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func notIndexed() -> Self {
        self.isIndexed = false
        return self
    }
    
    /// Uses the column as the language id hidden column.
    ///
    /// For example:
    ///
    /// ```swift
    /// try db.create(virtualTable: "document", using: FTS4()) { t in
    ///     t.column("a")
    ///     t.column("lid").asLanguageId()
    /// }
    /// ```
    ///
    /// Related SQLite documentation: <https://www.sqlite.org/fts3.html#the_languageid_option>
    ///
    /// - returns: `self` so that you can further refine the column definition.
    @discardableResult
    public func asLanguageId() -> Self {
        self.isLanguageId = true
        return self
    }
}

extension Database {
    /// Deletes the synchronization triggers for a synchronized FTS4 table.
    ///
    /// See ``FTS4TableDefinition/synchronize(withTable:)``.
    public func dropFTS4SynchronizationTriggers(forTable tableName: String) throws {
        try execute(sql: """
            DROP TRIGGER IF EXISTS \("__\(tableName)_bu".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_bd".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_au".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_ai".quotedDatabaseIdentifier);
            """)
    }
}
