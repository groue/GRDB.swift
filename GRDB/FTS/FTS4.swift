/// FTS4 lets you define "fts4" virtual tables.
///
///     // CREATE VIRTUAL TABLE documents USING fts4(content)
///     try db.create(virtualTable: "documents", using: FTS4()) { t in
///         t.column("content")
///     }
///
/// See https://www.sqlite.org/fts3.html
public struct FTS4 : VirtualTableModule {
    
    /// Creates a FTS4 module suitable for the Database
    /// `create(virtualTable:using:)` method.
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts4(content)
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html
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
            if tokenizer.options.isEmpty {
                arguments.append("tokenize=\(tokenizer.name)")
            } else {
                arguments.append("tokenize=\(tokenizer.name) " + tokenizer.options.map { "\"\($0)\"" as String }.joined(separator: " "))
            }
        }
        
        if let content = definition.content {
            arguments.append("content=\"\(content)\"")
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
}

/// The FTS4TableDefinition class lets you define columns of a FTS4 virtual table.
///
/// You don't create instances of this class. Instead, you use the Database
/// `create(virtualTable:using:)` method:
///
///     try db.create(virtualTable: "documents", using: FTS4()) { t in // t is FTS4TableDefinition
///         t.column("content")
///     }
///
/// See https://www.sqlite.org/fts3.html
public final class FTS4TableDefinition {
    fileprivate var columns: [FTS4ColumnDefinition] = []
    
    /// The virtual table tokenizer
    ///
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.tokenizer = .porter
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#creating_and_destroying_fts_tables
    public var tokenizer: FTS3Tokenizer?
    
    /// The FTS4 `content` option
    ///
    /// See https://www.sqlite.org/fts3.html#the_content_option_
    public var content: String?
    
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
    ///     // CREATE VIRTUAL TABLE documents USING FTS4(content, prefix='2 4');
    ///     db.create(virtualTable: "documents", using:FTS4()) { t in
    ///         t.prefixes = [2, 4]
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_prefix_option
    public var prefixes: Set<Int>?
    
    /// Appends a table column.
    ///
    ///     try db.create(virtualTable: "documents", using: FTS4()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// - parameter name: the column name.
    @discardableResult public func column(_ name: String) -> FTS4ColumnDefinition {
        let column = FTS4ColumnDefinition(name: name)
        columns.append(column)
        return column
    }
}

/// The FTS4ColumnDefinition class lets you refine a column of an FTS4
/// virtual table.
///
/// You get instances of this class when you create an FTS4 table:
///
///     try db.create(virtualTable: "persons", using: FTS4()) { t in
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
    ///     try db.create(virtualTable: "persons", using: FTS4()) { t in
    ///         t.column("a")
    ///         t.column("b").notIndexed()
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_notindexed_option
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult public func notIndexed() -> Self {
        self.isIndexed = false
        return self
    }
    
    /// Uses the column as the Int32 language id hidden column.
    ///
    ///     try db.create(virtualTable: "persons", using: FTS4()) { t in
    ///         t.column("a")
    ///         t.column("lid").asLanguageId()
    ///     }
    ///
    /// See https://www.sqlite.org/fts3.html#the_languageid_option
    ///
    /// - returns: Self so that you can further refine the column definition.
    @discardableResult public func asLanguageId() -> Self {
        self.isLanguageId = true
        return self
    }
}
