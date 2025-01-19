/// An SQL result column.
///
/// `SQLSelection` is an opaque representation of an SQL result column.
/// You generally build `SQLSelection` from other expressions. For example:
///
/// ```swift
/// // Aliased expressions
/// (Column("score") + Column("bonus")).forKey("total")
///
/// // Literal selection
/// SQL("IFNULL(name, \(defaultName)) AS name").sqlSelection
/// ```
///
/// `SQLSelection` is better used as the return type of a function. For
/// function arguments, prefer the ``SQLSelectable`` protocol.
///
/// Related SQLite documentation: <https://www.sqlite.org/syntax/result-column.html>
public struct SQLSelection: Sendable {
    private var impl: Impl
    
    /// The private implementation of the public `SQLSelection`.
    private enum Impl {
        /// All columns: `*`
        case allColumns
        
        /// All columns, qualified: `player.*`
        case qualifiedAllColumns(TableAlias)
        
        /// All columns but the specified ones
        case allColumnsExcluding(Set<CaseInsensitiveIdentifier>)
        
        /// All columns but the specified ones, qualified.
        case qualifiedAllColumnsExcluding(TableAlias, Set<CaseInsensitiveIdentifier>)

        /// An expression
        case expression(SQLExpression)
        
        /// An aliased expression
        ///
        ///     <expression> AS name
        case aliasedExpression(SQLExpression, String)
        
        /// A literal SQL selection
        case literal(SQL)
    }
    
    /// All columns: `*`
    static let allColumns = SQLSelection(impl: .allColumns)
    
    /// All columns but the specified ones.
    static func allColumnsExcluding(_ excludedColumns: Set<CaseInsensitiveIdentifier>) -> Self {
        SQLSelection(impl: .allColumnsExcluding(excludedColumns))
    }
    
    /// All columns, qualified: `player.*`
    static func qualifiedAllColumns(_ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedAllColumns(alias))
    }
    
    /// All columns but the specified ones, qualified.
    static func qualifiedAllColumnsExcluding(_ alias: TableAlias, _ excludedColumns: Set<CaseInsensitiveIdentifier>) -> Self {
        self.init(impl: .qualifiedAllColumnsExcluding(alias, excludedColumns))
    }
    
    /// An expression
    static func expression(_ expression: SQLExpression) -> Self {
        self.init(impl: .expression(expression))
    }
    
    /// An aliased expression
    ///
    ///     <expression> AS name
    static func aliasedExpression(_ expression: SQLExpression, _ name: String) -> Self {
        self.init(impl: .aliasedExpression(expression, name))
    }
    
    /// A literal SQL selection
    static func literal(_ sqlLiteral: SQL) -> Self {
        self.init(impl: .literal(sqlLiteral))
    }
}

extension SQLSelection {
    /// Returns the number of columns in the selection.
    ///
    /// Returns nil when the number of columns is unknown.
    func columnCount(_ context: SQLGenerationContext) throws -> Int? {
        switch impl {
        case .allColumns, .allColumnsExcluding:
            // Likely a GRDB bug: we can't count the number of columns in an
            // unqualified table.
            return nil
            
        case let .qualifiedAllColumns(alias):
            return try context.columnCount(in: alias.tableName, excluding: [])
            
        case let .qualifiedAllColumnsExcluding(alias, excludedColumns):
            return try context.columnCount(in: alias.tableName, excluding: excludedColumns)
            
        case .expression,
             .aliasedExpression:
            return 1
            
        case .literal:
            // We do not embed any SQL parser: we can't count the number of
            // columns in a literal selection.
            return nil
        }
    }
    
    /// If the selection can be counted, return how to count it.
    func count(distinct: Bool) -> SQLCount? {
        switch impl {
        case .allColumns:
            // SELECT DISTINCT * FROM tableName ...
            if distinct {
                // Can't count
                return nil
            }
            
            // SELECT * FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return .all
            
        case .allColumnsExcluding:
            // SELECT DISTINCT a, b, c FROM tableName ...
            if distinct {
                // TODO: if the selection were qualified, and if we had a
                // database connection, we could detect the case where there
                // remains only one column, and we could perform a
                // SELECT COUNT(DISTINCT remainingColumn) FROM tableName
                //
                // Since most people will not use `.allColumns(excluding:)`
                // when they want to select only one column, I guess that
                // this optimization has little chance to be needed.
                //
                // Can't count
                return nil
            }
            
            // SELECT a, b, c FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return .all
            
        case .qualifiedAllColumns, .qualifiedAllColumnsExcluding:
            return nil
            
        case let .expression(expression),
             let .aliasedExpression(expression, _):
            if distinct {
                // SELECT DISTINCT expr FROM tableName ...
                // ->
                // SELECT COUNT(DISTINCT expr) FROM tableName ...
                return .distinct(expression)
            } else {
                // SELECT expr FROM tableName ...
                // ->
                // SELECT COUNT(*) FROM tableName ...
                return .all
            }
            
        case .literal:
            return nil
        }
    }
    
    /// Returns the SQL that feeds the selection of a `SELECT` statement.
    ///
    /// For example:
    ///
    ///     1
    ///     name
    ///     COUNT(*)
    ///     (score + bonus) AS total
    ///
    /// See <https://sqlite.org/syntax/result-column.html>
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case .allColumns:
            return "*"
            
        case .allColumnsExcluding:
            // Likely a GRDB bug: we don't know the table name so we can't
            // load remaining columns. This selection should have been
            // turned into a `.qualifiedAllColumnsExcluding`.
            fatalError("Not implemented, or invalid query")
            
        case let .qualifiedAllColumns(alias):
            if let qualifier = context.qualifier(for: alias) {
                return qualifier.quotedDatabaseIdentifier + ".*"
            }
            return "*"
        
        case let .qualifiedAllColumnsExcluding(alias, excludedColumns):
            let columnsNames = try context.columnNames(in: alias.tableName)
            let remainingColumnsNames = if excludedColumns.isEmpty {
                columnsNames
            } else {
                columnsNames.filter {
                    !excludedColumns.contains(CaseInsensitiveIdentifier(rawValue: $0))
                }
            }
            if columnsNames.count == remainingColumnsNames.count {
                // We're not excluding anything
                if let qualifier = context.qualifier(for: alias) {
                    return qualifier.quotedDatabaseIdentifier + ".*"
                }
                return "*"
            } else {
                return try remainingColumnsNames
                    .map { try SQLExpression.column($0).qualified(with: alias).sql(context) }
                    .joined(separator: ", ")
            }
            
        case let .expression(expression):
            return try expression.sql(context)
            
        case let .aliasedExpression(expression, name):
            return try expression.sql(context) + " AS " + name.quotedDatabaseIdentifier
            
        case let .literal(sqlLiteral):
            return try sqlLiteral.sql(context)
        }
    }
    
    /// Returns true if the selection is an aggregate.
    ///
    /// When in doubt, returns false.
    ///
    ///     SELECT *              -- false
    ///     SELECT score          -- false
    ///     SELECT COUNT(*)       -- true
    ///     SELECT MAX(score)     -- true
    ///     SELECT MAX(score) + 1 -- true
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT MAX("score") FROM "player"
    ///     try Player.select(max(Column("score")), as: Int.self).fetchOne(db)
    ///
    ///     // SELECT "score" FROM "player" LIMIT 1
    ///     try Player.select(Column("score"), as: Int.self).fetchOne(db)
    var isAggregate: Bool {
        switch impl {
        case let .expression(expression),
             let .aliasedExpression(expression, _):
            return expression.isAggregate
            
        default:
            return false
        }
    }
    
    /// Returns a qualified selection
    func qualified(with alias: TableAlias) -> SQLSelection {
        switch impl {
        case .qualifiedAllColumns, .qualifiedAllColumnsExcluding:
            return self
            
        case .allColumns:
            return .qualifiedAllColumns(alias)
            
        case let .allColumnsExcluding(excludedColumns):
            return .qualifiedAllColumnsExcluding(alias, excludedColumns)
            
        case let .expression(expression):
            return .expression(expression.qualified(with: alias))
            
        case let .aliasedExpression(expression, name):
            return .aliasedExpression(expression.qualified(with: alias), name)
            
        case let .literal(sqlLiteral):
            return .literal(sqlLiteral.qualified(with: alias))
        }
    }
    
    /// Returns whether this selection MUST be counted with a "trivial"
    /// count: `SELECT COUNT(*) FROM (SELECT ...)`.
    ///
    /// Supports SQLRelation.fetchCount.
    ///
    /// See <https://github.com/groue/GRDB.swift/issues/1357>
    var requiresTrivialCount: Bool {
        switch impl {
        case .aliasedExpression, .literal:
            // Trivial count is required.
            //
            // For example, the WHERE clause here requires the aliased
            // column to be preserved in the counting request:
            // SELECT *, column AS alt FROM player WHERE alt
            return true
        case .allColumns, .qualifiedAllColumns:
            return false
        case .allColumnsExcluding, .qualifiedAllColumnsExcluding:
            return false
        case .expression:
            return false
        }
    }
}

extension [SQLSelection] {
    /// Returns the number of columns in the selection.
    ///
    /// This method raises a fatal error if the selection contains a literal,
    ///
    /// See `SQLSelection.columnCount(_:)` for testability.
    func columnCount(_ context: SQLGenerationContext) throws -> Int {
        try reduce(0) { acc, selection in
            guard let count = try selection.columnCount(context) else {
                // Found an SQL literal:
                // - Player.select(sql: "id, name, score")
                // - Player.select(literal: "id, name, score")
                fatalError("""
                    Selection literals don't known how many columns they contain. \
                    To resolve this error, select one or several expressions instead.
                    """)
            }
            
            return acc + count
        }
    }
}

enum SQLCount {
    /// Represents `COUNT(*)`
    case all
    
    /// Represents `COUNT(DISTINCT expression)`
    case distinct(SQLExpression)
}

// MARK: - SQLSelectable

/// A type that can be used as SQL result columns.
///
/// Related SQLite documentation <https://www.sqlite.org/syntax/result-column.html>
///
/// ## Topics
///
/// ### Standard Selections
///
/// - ``rowID``
/// - ``allColumns``
/// - ``allColumns(excluding:)-3sg4w``
/// - ``allColumns(excluding:)-3blq4``
///
/// ### Supporting Types
///
/// - ``AllColumns``
/// - ``AllColumnsExcluding``
/// - ``SQLSelection``
public protocol SQLSelectable {
    /// Returns an SQL selection.
    var sqlSelection: SQLSelection { get }
}

extension SQLSelectable where Self == Column {
    /// The hidden rowID column.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord {
    ///     static var databaseSelection: [any SQLSelectable] {
    ///         [.allColumns, .rowID]
    ///     }
    /// }
    ///
    /// // SELECT *, rowid FROM player
    /// Player.fetchAll(db)
    /// ```
    public static var rowID: Self { Column.rowID }
}

extension SQLSelection: SQLSelectable {
    // Not a real deprecation, just a usage warning
    @available(*, deprecated, message: "Already SQLSelection")
    public var sqlSelection: SQLSelection { self }
}

// MARK: - AllColumns

/// `AllColumns` is the `*` in `SELECT *`.
///
/// For example:
///
/// ```swift
/// struct Player: FetchableRecord, TableRecord {
///     static var databaseSelection: [any SQLSelectable] {
///         [.allColumns, .rowID]
///     }
/// }
///
/// // SELECT *, rowid FROM player
/// Player.fetchAll(db)
/// ```
public struct AllColumns: Sendable {
    /// The `*` selection.
    public init() { }
}

extension AllColumns: SQLSelectable {
    public var sqlSelection: SQLSelection {
        .allColumns
    }
}

extension SQLSelectable where Self == AllColumns {
    /// All columns of the requested table.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: FetchableRecord, TableRecord {
    ///     static var databaseSelection: [any SQLSelectable] {
    ///         [.allColumns, .rowID]
    ///     }
    /// }
    ///
    /// // SELECT *, rowid FROM player
    /// Player.fetchAll(db)
    /// ```
    public static var allColumns: AllColumns { AllColumns() }
}

// MARK: - AllColumnsExcluding

/// `AllColumnsExcluding` selects all columns in a database table, but the
/// ones you specify.
///
/// For example:
///
/// ```swift
/// struct Player: TableRecord {
///     static var databaseSelection: [any SQLSelectable] {
///         [.allColumns(excluding: ["generatedColumn"])]
///     }
/// }
///
/// // SELECT id, name, score FROM player
/// Player.fetchAll(db)
/// ```
public struct AllColumnsExcluding: Sendable {
    var excludedColumns: Set<CaseInsensitiveIdentifier>
    
    public init(_ excludedColumns: some Collection<String>) {
        self.excludedColumns = Set(excludedColumns.lazy.map {
            CaseInsensitiveIdentifier(rawValue: $0)
        })
    }
}

extension AllColumnsExcluding: SQLSelectable {
    public var sqlSelection: SQLSelection {
        .allColumnsExcluding(excludedColumns)
    }
}

extension SQLSelectable where Self == AllColumnsExcluding {
    /// All columns of the requested table, excluding the provided columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord {
    ///     static var databaseSelection: [any SQLSelectable] {
    ///         [.allColumns(excluding: ["generatedColumn"])]
    ///     }
    /// }
    ///
    /// // SELECT id, name, score FROM player
    /// Player.fetchAll(db)
    /// ```
    public static func allColumns(excluding excludedColumns: some Collection<String>) -> Self {
        AllColumnsExcluding(excludedColumns)
    }
    
    /// All columns of the requested table, excluding the provided columns.
    ///
    /// For example:
    ///
    /// ```swift
    /// struct Player: TableRecord {
    ///     static var databaseSelection: [any SQLSelectable] {
    ///         [.allColumns(excluding: [Column("generatedColumn")])]
    ///     }
    /// }
    ///
    /// // SELECT id, name, score FROM player
    /// Player.fetchAll(db)
    /// ```
    public static func allColumns(excluding excludedColumns: some Collection<any ColumnExpression>) -> Self {
        AllColumnsExcluding(excludedColumns.map(\.name))
    }
}
