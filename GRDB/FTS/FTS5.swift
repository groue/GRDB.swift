#if SQLITE_ENABLE_FTS5
    /// FTS5 lets you define "fts5" virtual tables.
    ///
    ///     // CREATE VIRTUAL TABLE documents USING fts5(content)
    ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html
    public struct FTS5 : VirtualTableModule {
        
        /// Creates a FTS5 module suitable for the Database
        /// `create(virtualTable:using:)` method.
        ///
        ///     // CREATE VIRTUAL TABLE documents USING fts5(content)
        ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
        ///         t.column("content")
        ///     }
        ///
        /// See https://www.sqlite.org/fts5.html
        public init() {
        }
        
        // MARK: - VirtualTableModule Adoption
        
        /// The virtual table module name
        public let moduleName = "fts5"
        
        /// Don't use this method.
        public func makeTableDefinition() -> FTS5TableDefinition {
            return FTS5TableDefinition()
        }
        
        /// Don't use this method.
        public func moduleArguments(_ definition: FTS5TableDefinition) -> [String] {
            var arguments: [String] = []
            
            if definition.columns.isEmpty {
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
                arguments.append("tokenize=\(tokenizer.components.joined(separator: " ").sqlExpression.sql)")
            }
            
            if let content = definition.content {
                arguments.append("content=\(content.sqlExpression.sql)")
            }
            
            if let prefixes = definition.prefixes {
                arguments.append("prefix=\(prefixes.map { "\($0)" }.joined(separator: " ").sqlExpression.sql)")
            }
            
            if let columnSize = definition.columnSize {
                arguments.append("columnSize=\(columnSize)")
            }
            
            if let detail = definition.detail {
                arguments.append("detail=\(detail)")
            }
            
            return arguments
        }
    }
    
    /// The FTS5TableDefinition class lets you define columns of a FTS5 virtual table.
    ///
    /// You don't create instances of this class. Instead, you use the Database
    /// `create(virtualTable:using:)` method:
    ///
    ///     try db.create(virtualTable: "documents", using: FTS5()) { t in // t is FTS5TableDefinition
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html
    public final class FTS5TableDefinition {
        fileprivate var columns: [FTS5ColumnDefinition] = []
        
        /// The virtual table tokenizer
        ///
        ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
        ///         t.tokenizer = .porter()
        ///     }
        ///
        /// See https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization
        public var tokenizer: FTS5Tokenizer?
        
        /// The FTS5 `content` option
        ///
        /// See https://www.sqlite.org/fts5.html#external_content_and_contentless_tables
        public var content: String?
        
        /// Support for the FTS5 `prefix` option
        ///
        /// See https://www.sqlite.org/fts5.html#prefix_indexes
        public var prefixes: Set<Int>?
        
        /// Support for the FTS5 `columnsize` option
        ///
        /// https://www.sqlite.org/fts5.html#the_columnsize_option
        public var columnSize: Int?
        
        /// Support for the FTS5 `detail` option
        ///
        /// https://www.sqlite.org/fts5.html#the_detail_option
        public var detail: String?
        
        /// Appends a table column.
        ///
        ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
        ///         t.column("content")
        ///     }
        ///
        /// - parameter name: the column name.
        @discardableResult public func column(_ name: String) -> FTS5ColumnDefinition {
            let column = FTS5ColumnDefinition(name: name)
            columns.append(column)
            return column
        }
    }
    
    /// The FTS5ColumnDefinition class lets you refine a column of an FTS5
    /// virtual table.
    ///
    /// You get instances of this class when you create an FTS5 table:
    ///
    ///     try db.create(virtualTable: "persons", using: FTS5()) { t in
    ///         t.column("content")      // FTS5ColumnDefinition
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html
    public final class FTS5ColumnDefinition {
        fileprivate let name: String
        fileprivate var isIndexed: Bool
        
        init(name: String) {
            self.name = name
            self.isIndexed = true
        }
        
        /// Excludes the column from the full-text index.
        ///
        ///     try db.create(virtualTable: "persons", using: FTS5()) { t in
        ///         t.column("a")
        ///         t.column("b").notIndexed()
        ///     }
        ///
        /// See https://www.sqlite.org/fts5.html#the_unindexed_column_option
        ///
        /// - returns: Self so that you can further refine the column definition.
        @discardableResult public func notIndexed() -> Self {
            self.isIndexed = false
            return self
        }
    }
#endif
