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
                arguments.append("tokenize=\(tokenizer.components.joined(separator: " ").sqlExpression.sql)")
            }
            
            switch definition.contentMode {
            case .raw(let content, let contentRowID):
                if let content = content {
                    arguments.append("content=\(content.sqlExpression.sql)")
                }
                if let contentRowID = contentRowID {
                    arguments.append("content_rowid=\(contentRowID.sqlExpression.sql)")
                }
            case .synchronized(let contentTable):
                arguments.append("content=\(contentTable.sqlExpression.sql)")
                if let rowIDColumn = try db.primaryKey(contentTable).rowIDColumn {
                    arguments.append("content_rowid=\(rowIDColumn.sqlExpression.sql)")
                }
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
                let indexedColumns = definition.columns.map { $0.name }
                
                let ftsColumns = (["rowid"] + indexedColumns)
                    .map { $0.quotedDatabaseIdentifier }
                    .joined(separator: ", ")
                
                let newContentColumns = ([rowIDColumn] + indexedColumns)
                    .map { "new.\($0.quotedDatabaseIdentifier)" }
                    .joined(separator: ", ")
                
                let oldContentColumns = ([rowIDColumn] + indexedColumns)
                    .map { "old.\($0.quotedDatabaseIdentifier)" }
                    .joined(separator: ", ")
                
                try db.execute("""
                    CREATE TRIGGER \("__\(contentTable)_ai".quotedDatabaseIdentifier) AFTER INSERT ON \(content) BEGIN
                        INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES (\(newContentColumns));
                    END;
                    CREATE TRIGGER \("__\(contentTable)_ad".quotedDatabaseIdentifier) AFTER DELETE ON \(content) BEGIN
                        INSERT INTO \(ftsTable)(\(ftsTable), \(ftsColumns)) VALUES('delete', \(oldContentColumns));
                    END;
                    CREATE TRIGGER \("__\(contentTable)_au".quotedDatabaseIdentifier) AFTER UPDATE ON \(content) BEGIN
                        INSERT INTO \(ftsTable)(\(ftsTable), \(ftsColumns)) VALUES('delete', \(oldContentColumns));
                        INSERT INTO \(ftsTable)(\(ftsColumns)) VALUES (\(newContentColumns));
                    END;
                    """)
                
                // https://sqlite.org/fts5.html#the_rebuild_command
                
                try db.execute("INSERT INTO \(ftsTable)(\(ftsTable)) VALUES('rebuild')")
            }
        }
        
        static func api(_ db: Database) -> UnsafePointer<fts5_api> {
            let sqliteConnection = db.sqliteConnection
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
    ///     try db.create(virtualTable: "documents", using: FTS5()) { t in // t is FTS5TableDefinition
    ///         t.column("content")
    ///     }
    ///
    /// See https://www.sqlite.org/fts5.html
    public final class FTS5TableDefinition {
        enum ContentMode {
            case raw(content: String?, contentRowID: String?)
            case synchronized(contentTable: String)
        }
        
        fileprivate var columns: [FTS5ColumnDefinition] = []
        fileprivate var contentMode: ContentMode = .raw(content: nil, contentRowID: nil)
        
        /// The virtual table tokenizer
        ///
        ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
        ///         t.tokenizer = .porter()
        ///     }
        ///
        /// See https://www.sqlite.org/fts5.html#fts5_table_creation_and_initialization
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
        /// See https://www.sqlite.org/fts5.html#external_content_and_contentless_tables
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
        /// See https://sqlite.org/fts5.html#external_content_tables
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
        /// See https://sqlite.org/fts5.html#external_content_tables
        public func synchronize(withTable tableName: String) {
            contentMode = .synchronized(contentTable: tableName)
        }
    }
    
    /// The FTS5ColumnDefinition class lets you refine a column of an FTS5
    /// virtual table.
    ///
    /// You get instances of this class when you create an FTS5 table:
    ///
    ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
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
        ///     try db.create(virtualTable: "documents", using: FTS5()) { t in
        ///         t.column("a")
        ///         t.column("b").notIndexed()
        ///     }
        ///
        /// See https://www.sqlite.org/fts5.html#the_unindexed_column_option
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
#endif
