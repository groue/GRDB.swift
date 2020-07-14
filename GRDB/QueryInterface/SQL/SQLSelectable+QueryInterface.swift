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
    public init() { }
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
        _SQLQualifiedAllColumns(alias: alias)
    }
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int {
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
    let alias: TableAlias
    
    init(alias: TableAlias) {
        self.alias = alias
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
        try db.columns(in: alias.tableName).count
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
