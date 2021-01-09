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
    // As long as the CTE is embedded here, the following request will fail
    // at runtime, in `_columnCount(_:)`, because we can't access the number of
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
    
    /// When nil, select all columns from a regular database table.
    /// When not nil, select all columns from a common table expression.
    var cte: SQLCTE?
    
    /// The `*` selection.
    ///
    /// For example:
    ///
    ///     // SELECT * FROM player
    ///     Player.select(AllColumns())
    public init() { }
    
    /// The `*` selection for a common table expression.
    ///
    ///     WITH t AS (...) SELECT * FROM t
    init(cte: SQLCTE) {
        self.cte = cte
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
        if let cte = cte {
            return try cte.columnsCount(db)
        }
        
        fatalError("Can't compute number of columns without an alias")
    }
    
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        // SELECT DISTINCT * FROM tableName ...
        if distinct {
            // Can't count
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .all
    }
    
    /// :nodoc:
    public func _countedSQL(_ context: SQLGenerationContext) throws -> String { "*" }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        SQLQualifiedAllColumns(alias: alias, cte: cte)
    }
    
    /// :nodoc:
    public func _resultColumnSQL(_ context: SQLGenerationContext) throws -> String { "*" }
}

// MARK: - SQLQualifiedAllColumns

/// _SQLQualifiedAllColumns is the `t.*` in `SELECT t.*`.
///
/// :nodoc:
struct SQLQualifiedAllColumns: SQLSelectable {
    /// When nil, select all columns from a regular database table.
    /// When not nil, select all columns from a common table expression.
    var cte: SQLCTE?
    let alias: TableAlias
    
    init(alias: TableAlias, cte: SQLCTE?) {
        self.alias = alias
        self.cte = cte
    }
    
    func _columnCount(_ db: Database) throws -> Int {
        if let cte = cte {
            return try cte.columnsCount(db)
        } else {
            return try db.columns(in: alias.tableName).count
        }
    }
    
    func _count(distinct: Bool) -> _SQLCount? { nil }
    
    func _countedSQL(_ context: SQLGenerationContext) throws -> String {
        if context.qualifier(for: alias) != nil {
            // SELECT COUNT(t.*) is invalid SQL
            fatalError("Not implemented, or invalid query")
        }
        
        return "*"
    }
    
    func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        // Never requalify
        return self
    }
    
    func _resultColumnSQL(_ context: SQLGenerationContext) throws -> String {
        if let qualifier = context.qualifier(for: alias) {
            return qualifier.quotedDatabaseIdentifier + ".*"
        }
        return "*"
    }
}

// MARK: - SQLAliasedExpression

/// :nodoc:
struct SQLAliasedExpression: SQLSelectable {
    let expression: SQLExpression
    let name: String
    
    init(_ expression: SQLExpression, name: String) {
        self.expression = expression
        self.name = name
    }
    
    func _columnCount(_ db: Database) throws -> Int { 1 }
    
    func _count(distinct: Bool) -> _SQLCount? {
        expression._count(distinct: distinct)
    }
    
    func _countedSQL(_ context: SQLGenerationContext) throws -> String {
        try expression._countedSQL(context)
    }
    
    var _isAggregate: Bool { expression._isAggregate }
    
    func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        SQLAliasedExpression(expression._qualifiedExpression(with: alias), name: name)
    }
    
    func _resultColumnSQL(_ context: SQLGenerationContext) throws -> String {
        try expression._resultColumnSQL(context)
            + " AS "
            + name.quotedDatabaseIdentifier
    }
}
