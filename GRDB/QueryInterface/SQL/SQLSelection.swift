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
public struct SQLSelection {
    private var impl: Impl
    
    /// The private implementation of the public `SQLSelection`.
    private enum Impl {
        /// All columns: `*`
        case allColumns
        
        /// All columns, qualified: `player.*`
        case qualifiedAllColumns(TableAlias)
        
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
    
    /// All columns, qualified: `player.*`
    static func qualifiedAllColumns(_ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedAllColumns(alias))
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
        case .allColumns:
            // Likely a GRDB bug: we can't count the number of columns in an
            // unqualified table.
            return nil
            
        case let .qualifiedAllColumns(alias):
            return try context.columnCount(in: alias.tableName)
            
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
            
        case .qualifiedAllColumns:
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
    
    /// Returns the SQL that feeds the argument of the `COUNT` function.
    ///
    /// For example:
    ///
    ///     COUNT(*)
    ///     COUNT(id)
    ///           ^---- countedSQL
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func countedSQL(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case .allColumns:
            return "*"
            
        case let .qualifiedAllColumns(alias):
            if context.qualifier(for: alias) != nil {
                // SELECT COUNT(t.*) is invalid SQL
                fatalError("Not implemented, or invalid query")
            }
            return "*"
            
        case let .expression(expression),
             let .aliasedExpression(expression, _):
            return try expression.sql(context)
            
        case .literal:
            fatalError("""
                Selection literals can't be counted. \
                To resolve this error, select one or several literal expressions instead. \
                See SQL.sqlExpression.
                """)
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
            
        case let .qualifiedAllColumns(alias):
            if let qualifier = context.qualifier(for: alias) {
                return qualifier.quotedDatabaseIdentifier + ".*"
            }
            return "*"
            
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
        case .qualifiedAllColumns:
            return self
            
        case .allColumns:
            return .qualifiedAllColumns(alias)
            
        case let .expression(expression):
            return .expression(expression.qualified(with: alias))
            
        case let .aliasedExpression(expression, name):
            return .aliasedExpression(expression.qualified(with: alias), name)
            
        case let .literal(sqlLiteral):
            return .literal(sqlLiteral.qualified(with: alias))
        }
    }
    
    /// Supports SQLRelation.fetchCount.
    ///
    /// See <https://github.com/groue/GRDB.swift/issues/1357>
    var isTriviallyCountable: Bool {
        switch impl {
        case .aliasedExpression, .literal:
            return false
        case .allColumns, .qualifiedAllColumns, .expression:
            return true
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
/// ### Supporting Types
///
/// - ``AllColumns``
/// - ``SQLSelection``
public protocol SQLSelectable {
    /// Returns an SQL selection.
    var sqlSelection: SQLSelection { get }
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
/// try dbQueue.read { db in
///     // SELECT * FROM player
///     let players = try Player.select(AllColumns()).fetchAll(db)
/// }
/// ```
public struct AllColumns {
    /// The `*` selection.
    public init() { }
}

extension AllColumns: SQLSelectable {
    public var sqlSelection: SQLSelection {
        .allColumns
    }
}
