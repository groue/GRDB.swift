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
public struct AllColumns {
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
}

extension AllColumns: SQLSelectable {
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
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        _SQLQualifiedAllColumns(alias: alias, cte: cte)
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
        if let cte = cte {
            return try cte.columnsCount(db)
        }
        
        fatalError("Can't compute number of columns without an alias")
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLQualifiedAllColumns

/// _SQLQualifiedAllColumns is the `t.*` in `SELECT t.*`.
///
/// :nodoc:
public struct _SQLQualifiedAllColumns {
    /// When nil, select all columns from a regular database table.
    /// When not nil, select all columns from a common table expression.
    var cte: SQLCTE?
    let alias: TableAlias
    
    init(alias: TableAlias, cte: SQLCTE?) {
        self.alias = alias
        self.cte = cte
    }
}

extension _SQLQualifiedAllColumns: SQLSelectable {
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? { nil }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        // Never requalify
        return self
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
        if let cte = cte {
            return try cte.columnsCount(db)
        } else {
            return try db.columns(in: alias.tableName).count
        }
    }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}

// MARK: - _SQLAliasedExpression

/// :nodoc:
public struct _SQLAliasedExpression: SQLSelectable {
    let expression: SQLExpression
    let name: String
    
    init(_ expression: SQLExpression, name: String) {
        self.expression = expression
        self.name = name
    }
    
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        expression._count(distinct: distinct)
    }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        _SQLAliasedExpression(expression._qualifiedExpression(with: alias), name: name)
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int { 1 }
    
    /// :nodoc:
    public func _accept<Visitor: _SQLSelectableVisitor>(_ visitor: inout Visitor) throws {
        try visitor.visit(self)
    }
}
