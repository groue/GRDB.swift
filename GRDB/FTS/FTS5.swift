#if SQLITE_ENABLE_FTS5
import Foundation

/// FTS5 lets you define "fts5" virtual tables.
///
///     // CREATE VIRTUAL TABLE document USING fts5(content)
///     try db.create(virtualTable: "document", using: FTS5()) { t in
///         t.column("content")
///     }
///
/// See <https://www.sqlite.org/fts5.html>
public struct FTS5: VirtualTableModule {
    /// Options for Latin script characters. Matches the raw "remove_diacritics"
    /// tokenizer argument.
    ///
    /// See <https://www.sqlite.org/fts5.html>
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
    
    /// Creates a FTS5 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE document USING fts5(content)
    ///     try db.create(virtualTable: "document", using: FTS5()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// See <https://www.sqlite.org/fts5.html>
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
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts5"
    
    // TODO: remove when `makeTableDefinition()` is no longer a requirement
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func makeTableDefinition() -> FTS5TableDefinition {
        preconditionFailure()
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
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
                .joined(separator: " ")
                .sqlExpression
                .quotedSQL(db)
            arguments.append("tokenize=\(tokenizerSQL)")
        }
        
        switch definition.contentMode {
        case let .raw(content, contentRowID):
            if let content = content {
                let quotedContent = try content.sqlExpression.quotedSQL(db)
                arguments.append("content=\(quotedContent)")
            }
            if let contentRowID = contentRowID {
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
    /// See Database.create(virtualTable:using:)
    public func database(_ db: Database, didCreate tableName: String, using definition: FTS5TableDefinition) throws {
        switch definition.contentMode {
        case .raw:
            break
        case .synchronized(let contentTable):
            // https://sqlite.org/fts5.html#external_content_tables
            
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
    
    static func api(_ db: Database) -> UnsafePointer<fts5_api> {
        // Access to FTS5 is one of the rare SQLite api which was broken in
        // SQLite 3.20.0+, for security reasons:
        //
        // Starting SQLite 3.20.0+, we need to use the new sqlite3_bind_pointer api.
        // The previous way to access FTS5 does not work any longer.
        //
        // So let's see which SQLite version we are linked against:
        
        #if GRDBCUSTOMSQLITE || GRDBCIPHER
        // GRDB is linked against SQLCipher or a custom SQLite build: SQLite 3.20.0 or more.
        return api_v2(db, sqlite3_prepare_v3, sqlite3_bind_pointer)
        #else
        // GRDB is linked against the system SQLite.
        //
        // Do we use SQLite 3.19.3 (iOS 11.4), or SQLite 3.24.0 (iOS 12.0)?
        if #available(iOS 12.0, OSX 10.14, tvOS 12.0, watchOS 5.0, *) {
            // SQLite 3.24.0 or more
            return api_v2(db, sqlite3_prepare_v3, sqlite3_bind_pointer)
        } else {
            // SQLite 3.19.3 or less
            return api_v1(db)
        }
        #endif
    }
    
    private static func api_v1(_ db: Database) -> UnsafePointer<fts5_api> {
        guard let data = try! Data.fetchOne(db, sql: "SELECT fts5()") else {
            fatalError("FTS5 is not available")
        }
        return data.withUnsafeBytes {
            $0.bindMemory(to: UnsafePointer<fts5_api>.self).first!
        }
    }
    
    // Technique given by Jordan Rose:
    // https://forums.swift.org/t/c-interoperability-combinations-of-library-and-os-versions/14029/4
    private static func api_v2(
        _ db: Database,
        // swiftlint:disable:next line_length
        _ sqlite3_prepare_v3: @convention(c) (OpaquePointer?, UnsafePointer<Int8>?, Int32, UInt32, UnsafeMutablePointer<OpaquePointer?>?, UnsafeMutablePointer<UnsafePointer<Int8>?>?) -> Int32,
        // swiftlint:disable:next line_length
        _ sqlite3_bind_pointer: @convention(c) (OpaquePointer?, Int32, UnsafeMutableRawPointer?, UnsafePointer<Int8>?, (@convention(c) (UnsafeMutableRawPointer?) -> Void)?) -> Int32)
    -> UnsafePointer<fts5_api>
    {
        var statement: SQLiteStatement? = nil
        var api: UnsafePointer<fts5_api>? = nil
        let type: StaticString = "fts5_api_ptr"
        
        let code = sqlite3_prepare_v3(db.sqliteConnection, "SELECT fts5(?)", -1, 0, &statement, nil)
        guard code == SQLITE_OK else {
            fatalError("FTS5 is not available")
        }
        defer { sqlite3_finalize(statement) }
        type.utf8Start.withMemoryRebound(to: Int8.self, capacity: type.utf8CodeUnitCount) { typePointer in
            _ = sqlite3_bind_pointer(statement, 1, &api, typePointer, nil)
        }
        sqlite3_step(statement)
        guard let result = api else {
            fatalError("FTS5 is not available")
        }
        return result
    }
}

/// The FTS5TableDefinition class lets you define columns of a FTS5 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "document", using: FTS5()) { t in // t is FTS5TableDefinition
///         t.column("content")
///     }
///
/// See <https://www.sqlite.org/fts5.html>
public final class FTS5TableDefinition {
    enum ContentMode {
        case raw(content: String?, contentRowID: String?)
        case synchronized(contentTable: String)
    }
    
    fileprivate let configuration: VirtualTableConfiguration
    fileprivate var columns: [FTS5ColumnDefinition] = []
    fileprivate var contentMode: ContentMode = .raw(content: nil, contentRowID: nil)
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "document", using: FTS5()) { t in
    ///         t.tokenizer = .porter()
    ///     }
    ///
    /// See <https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization>
    public var tokenizer: FTS5TokenizerDescriptor?
    
    /// The FTS5 `content` option
    ///
    /// When you want the full-text table to be synchronized with the
    /// content of an external table, prefer the `synchronize(withTable:)`
    /// method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the `synchronize(withTable:)` method.
    ///
    /// See <https://www.sqlite.org/fts5.html#external_content_and_contentless_tables>
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
    /// content of an external table, prefer the `synchronize(withTable:)`
    /// method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the `synchronize(withTable:)` method.
    ///
    /// See <https://sqlite.org/fts5.html#external_content_tables>
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
    
    /// Support for the FTS5 `prefix` option
    ///
    /// See <https://www.sqlite.org/fts5.html#prefix_indexes>
    public var prefixes: Set<Int>?
    
    /// Support for the FTS5 `columnsize` option
    ///
    /// <https://www.sqlite.org/fts5.html#the_columnsize_option>
    public var columnSize: Int?
    
    /// Support for the FTS5 `detail` option
    ///
    /// <https://www.sqlite.org/fts5.html#the_detail_option>
    public var detail: String?
    
    init(configuration: VirtualTableConfiguration) {
        self.configuration = configuration
    }
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "document", using: FTS5()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
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
    /// See <https://sqlite.org/fts5.html#external_content_tables>
    public func synchronize(withTable tableName: String) {
        contentMode = .synchronized(contentTable: tableName)
    }
}

/// The FTS5ColumnDefinition class lets you refine a column of an FTS5
/// virtual table.
///
/// You get instances of this class when you create an FTS5 table:
///
///     try db.create(virtualTable: "document", using: FTS5()) { t in
///         t.column("content")      // FTS5ColumnDefinition
///     }
///
/// See <https://www.sqlite.org/fts5.html>
public final class FTS5ColumnDefinition {
    fileprivate let name: String
    fileprivate var isIndexed: Bool
    
    init(name: String) {
        self.name = name
        self.isIndexed = true
    }
    
    /// Excludes the column from the full-text index.
    ///
    ///     try db.create(virtualTable: "document", using: FTS5()) { t in
    ///         t.column("a")
    ///         t.column("b").notIndexed()
    ///     }
    ///
    /// See <https://www.sqlite.org/fts5.html#the_unindexed_column_option>
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func notIndexed() -> Self {
        self.isIndexed = false
        return self
    }
}

extension Column {
    /// The FTS5 rank column
    public static let rank = Column("rank")
}

extension Database {
    /// Deletes the synchronization triggers for a synchronized FTS5 table
    public func dropFTS5SynchronizationTriggers(forTable tableName: String) throws {
        try execute(sql: """
            DROP TRIGGER IF EXISTS \("__\(tableName)_ai".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_ad".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_au".quotedDatabaseIdentifier);
            """)
    }
}
#endif
