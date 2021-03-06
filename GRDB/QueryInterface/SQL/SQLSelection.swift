/// The type that can be selected, as described at
/// https://www.sqlite.org/syntax/result-column.html
public struct SQLSelection {
    private var impl: Impl
    
    /// The private implementation of the public `SQLSelection`.
    private enum Impl {
        /// All columns: `*`
        case allColumns
        
        /// All columns, qualified: `player.*`
        case qualifiedAllColumns(TableAlias)
        
        // As long as the CTE is embedded here, the following request will fail
        // at runtime, in `columnCount(_:)`, because we can't access the number of
        // columns in the CTE:
        //
        //     let association = Player.association(to: cte)
        //     Player.including(required: association.select(AllColumns(), ...))
        //
        // The need for this should not be frequent. And the user has
        // two workarounds:
        //
        // - provide explicit columns in the CTE definition.
        // - prefer `annotated(with:)` when she wants to extend the selection.
        //
        // TODO: Make `cteRequestOrAssociation.select(AllColumns())` possible.
        /// All columns of a common table expression
        case allCTEColumns(SQLCTE)
        
        /// All columns of a common table expression, qualified
        case qualifiedAllCTEColumns(SQLCTE, TableAlias)
        
        /// An expression
        case expression(SQLExpression)
        
        /// An aliased expression
        ///
        ///     <expression> AS name
        case aliasedExpression(SQLExpression, String)
        
        /// A literal SQL selection
        case literal(SQLLiteral)
    }
    
    /// All columns: `*`
    static let allColumns = SQLSelection(impl: .allColumns)
    
    /// All columns, qualified: `player.*`
    static func qualifiedAllColumns(_ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedAllColumns(alias))
    }
    
    /// All columns of a common table expression
    static func allCTEColumns(_ cte: SQLCTE) -> Self {
        self.init(impl: .allCTEColumns(cte))
    }
    
    /// All columns of a common table expression, qualified
    static func qualifiedAllCTEColumns(_ cte: SQLCTE, _ alias: TableAlias) -> Self {
        self.init(impl: .qualifiedAllCTEColumns(cte, alias))
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
    static func literal(_ sqlLiteral: SQLLiteral) -> Self {
        self.init(impl: .literal(sqlLiteral))
    }
}

extension SQLSelection {
    /// Returns the number of columns in the selection.
    func columnCount(_ db: Database) throws -> Int {
        switch impl {
        case .allColumns:
            // Likely a GRDB bug
            fatalError("Can't compute number of columns without an alias")
            
        case let .qualifiedAllColumns(alias):
            return try db.columns(in: alias.tableName).count
            
        case let .allCTEColumns(cte):
            return try cte.columnsCount(db)
            
        case let .qualifiedAllCTEColumns(cte, _):
            return try cte.columnsCount(db)
            
        case .expression,
             .aliasedExpression:
            return 1
            
        case .literal:
            fatalError("""
                Selection literals don't known how many columns they contain. \
                To resolve this error, select one or several literal expressions instead. \
                See SQLLiteral.sqlExpression.
                """)
        }
    }
    
    /// Support for `count(selection)`.
    /// TODO: deprecate `count(selection)`, and get rid of this property.
    var countExpression: SQLExpression {
        switch impl {
        case .allColumns,
             .allCTEColumns:
            return .countAll
            
        case .qualifiedAllColumns,
             .qualifiedAllCTEColumns:
            // COUNT(player.*) is not valid SQL
            fatalError("Uncountable selection")
            
        case let .expression(expression),
             let .aliasedExpression(expression, _):
            return .count(expression)
            
        case let .literal(sqlLiteral):
            return .count(sqlLiteral.sqlExpression)
        }
    }
    
    /// If the selection can be counted, return how to count it.
    func count(distinct: Bool) -> SQLCount? {
        switch impl {
        case .allColumns,
             .allCTEColumns:
            // SELECT DISTINCT * FROM tableName ...
            if distinct {
                // Can't count
                return nil
            }
            
            // SELECT * FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return .all
            
        case .qualifiedAllColumns,
             .qualifiedAllCTEColumns:
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
        case .allColumns,
             .allCTEColumns:
            return "*"
            
        case let .qualifiedAllColumns(alias),
             let .qualifiedAllCTEColumns(_, alias):
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
                See SQLLiteral.sqlExpression.
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
    /// See https://sqlite.org/syntax/result-column.html
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case .allColumns,
             .allCTEColumns:
            return "*"
            
        case let .qualifiedAllColumns(alias),
             let .qualifiedAllCTEColumns(_, alias):
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
        case .qualifiedAllColumns,
             .qualifiedAllCTEColumns:
            return self
            
        case .allColumns:
            return .qualifiedAllColumns(alias)
            
        case let .allCTEColumns(cte):
            return .qualifiedAllCTEColumns(cte, alias)
            
        case let .expression(expression):
            return .expression(expression.qualified(with: alias))
            
        case let .aliasedExpression(expression, name):
            return .aliasedExpression(expression.qualified(with: alias), name)
            
        case let .literal(sqlLiteral):
            return .literal(sqlLiteral.qualified(with: alias))
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

/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
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

/// AllColumns is the `*` in `SELECT *`.
///
/// You use AllColumns in your custom implementation of
/// TableRecord.databaseSelection.
///
/// For example:
///
///     struct Player : TableRecord {
///         static var databaseTableName = "player"
///         static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
///     }
///
///     // SELECT *, rowid FROM player
///     let request = Player.all()
public struct AllColumns: SQLSelectable {
    /// The `*` selection.
    ///
    /// For example:
    ///
    ///     // SELECT * FROM player
    ///     Player.select(AllColumns())
    public init() { }
    
    public var sqlSelection: SQLSelection {
        .allColumns
    }
}
