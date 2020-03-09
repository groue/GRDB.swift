/// FTS4 lets you define "fts4" virtual tables.
///
///     // CREATE VIRTUAL TABLE document USING fts4(content)
///     try db.create(virtualTable: "document", using: FTS4()) { t in
///         t.column("content")
///     }
///
/// See https://www.sqlite.org/fts3.html
public struct FTS4: VirtualTableModule {
    
    /// Creates a FTS4 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE document USING fts4(content)
    ///     try db.create(virtualTable: "document", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html
    public init() {
    }
    
    // MARK: - VirtualTableModule Adoption
    
    /// The virtual table module name
    public let moduleName = "fts4"
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
    public func makeTableDefinition() -> FTS4TableDefinition {
        FTS4TableDefinition()
    }
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
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
            if let content = content {
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
    
    /// Reserved; part of the VirtualTableModule protocol.
    ///
    /// See Database.create(virtualTable:using:)
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
            
            try db.execute(sql: """
                CREATE TRIGGER \("__\(tableName)_bu".quotedDatabaseIdentifier) BEFORE UPDATE ON \(content) BEGIN
                    DELETE FROM \(ftsTable) WHERE docid=\(oldRowID);
                END;
                CREATE TRIGGER \("__\(tableName)_bd".quotedDatabaseIdentifier) BEFORE DELETE ON \(content) BEGIN
                    DELETE FROM \(ftsTable) WHERE docid=\(oldRowID);
                END;
                CREATE TRIGGER \("__\(tableName)_au".quotedDatabaseIdentifier) AFTER UPDATE ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES(\(newContentColumns));
                END;
                CREATE TRIGGER \("__\(tableName)_ai".quotedDatabaseIdentifier) AFTER INSERT ON \(content) BEGIN
                    INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES(\(newContentColumns));
                END;
                """)
            
            // https://www.sqlite.org/fts3.html#*fts4rebuidcmd
            
            try db.execute(sql: "INSERT INTO \(ftsTable)(\(ftsTable)) VALUES('rebuild')")
        }
    }
}

/// The FTS4TableDefinition class lets you define columns of a FTS4 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "document", using: FTS4()) { t in // t is FTS4TableDefinition
///         t.column("content")
///     }
///
/// See https://www.sqlite.org/fts3.html
public final class FTS4TableDefinition {
    enum ContentMode {
        case raw(content: String?)
        case synchronized(contentTable: String)
    }
    
    fileprivate var columns: [FTS4ColumnDefinition] = []
    fileprivate var contentMode: ContentMode = .raw(content: nil)
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "document", using: FTS4()) { t in
    ///         t.tokenizer = .porter
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables
    public var tokenizer: FTS3TokenizerDescriptor?
    
    /// The FTS4 `content` option
    ///
    /// When you want the full-text table to be synchronized with the
    /// content of an external table, prefer the `synchronize(withTable:)`
    /// method.
    ///
    /// Setting this property invalidates any synchronization previously
    /// established with the `synchronize(withTable:)` method.
    ///
    /// See https://www.sqlite.org/fts3.html#the_content_option_
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
    
    /// The FTS4 `compress` option
    ///
    /// See https://www.sqlite.org/fts3.html#the_compress_and_uncompress_options
    public var compress: String?
    
    /// The FTS4 `uncompress` option
    ///
    /// See https://www.sqlite.org/fts3.html#the_compress_and_uncompress_options
    public var uncompress: String?
    
    /// The FTS4 `matchinfo` option
    ///
    /// See https://www.sqlite.org/fts3.html#the_matchinfo_option
    public var matchinfo: String?
    
    /// Support for the FTS5 `prefix` option
    ///
    ///     // CREATE VIRTUAL TABLE document USING FTS4(content, prefix='2 4');
    ///     db.create(virtualTable: "document", using:FTS4()) { t in
    ///         t.prefixes = [2, 4]
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_prefix_option
    public var prefixes: Set<Int>?
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "document", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
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
    /// See https://sqlite.org/fts5.html#external_content_tables
    public func synchronize(withTable tableName: String) {
        contentMode = .synchronized(contentTable: tableName)
    }
}

/// The FTS4ColumnDefinition class lets you refine a column of an FTS4
/// virtual table.
///
/// You get instances of this class when you create an FTS4 table:
///
///     try db.create(virtualTable: "document", using: FTS4()) { t in
///         t.column("content")      // FTS4ColumnDefinition
///     }
///
/// See https://www.sqlite.org/fts3.html
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
    ///     try db.create(virtualTable: "document", using: FTS4()) { t in
    ///         t.column("a")
    ///         t.column("b").notIndexed()
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_notindexed_option
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func notIndexed() -> Self {
        self.isIndexed = false
        return self
    }
    
    /// Uses the column as the Int32 language id hidden column.
    ///
    ///     try db.create(virtualTable: "document", using: FTS4()) { t in
    ///         t.column("a")
    ///         t.column("lid").asLanguageId()
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_languageid_option
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult
    public func asLanguageId() -> Self {
        self.isLanguageId = true
        return self
    }
}

extension Database {
    /// Deletes the synchronization triggers for a synchronized FTS4 table
    public func dropFTS4SynchronizationTriggers(forTable tableName: String) throws {
        try execute(sql: """
            DROP TRIGGER IF EXISTS \("__\(tableName)_bu".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_bd".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_au".quotedDatabaseIdentifier);
            DROP TRIGGER IF EXISTS \("__\(tableName)_ai".quotedDatabaseIdentifier);
            """)
    }
}
