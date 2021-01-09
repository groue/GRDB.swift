/// Implementation details of `SQLExpression`.
///
/// :nodoc:
public protocol _SQLExpression {
    /// If this expression is a table colum, returns the name of this column.
    ///
    /// When in doubt, returns nil.
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT * FROM "player" WHERE "id" = 1
    ///     try Player.fetchOne(db, key: 1)
    ///     try Player.filter(Column("id") == 1).fetchOne(db)
    ///
    ///     // SELECT * FROM "player" WHERE "name" = 'Arthur' LIMIT 1
    ///     try Player.filter(Column("name") == "Arthur").fetchOne(db)
    ///
    /// This method makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    ///
    /// - parameter acceptsBijection: If true, expressions that define a
    ///   bijection on a column return this column. For example: `-score`
    ///   returns `score`.
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String?
    
    /// Returns an SQL string that represents the expression.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    /// - parameter wrappedInParenthesis: If true, the returned SQL should be
    ///   wrapped inside parenthesis.
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String
    
    /// Returns the columns that identify a unique row in the request
    ///
    /// When in doubt, returns an empty set.
    ///
    ///     WHERE 0                         -- []
    ///     WHERE a                         -- []
    ///     WHERE a = b                     -- []
    ///     WHERE a = 1                     -- ["a"]
    ///     WHERE a = 1 AND b = 2           -- ["a", "b"]
    ///     WHERE a = 1 AND b = 2 AND c > 0 -- ["a", "b"]
    ///     WHERE a = 1 OR a = 2            -- []
    ///     WHERE a > 1                     -- []
    ///
    /// This method makes it possible to avoid inserting `LIMIT 1` to the SQL
    /// of some requests:
    ///
    ///     // SELECT * FROM "player" WHERE "id" = 1
    ///     try Player.fetchOne(db, key: 1)
    ///     try Player.filter(Column("id") == 1).fetchOne(db)
    ///
    ///     // SELECT * FROM "player" WHERE "name" = 'Arthur' LIMIT 1
    ///     try Player.filter(Column("name") == "Arthur").fetchOne(db)
    func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String>
    
    /// Returns the rowIds that identify rows in the request. A nil result means
    /// an unbounded list.
    ///
    /// When in doubt, returns nil.
    ///
    ///     WHERE 1                               -- nil
    ///     WHERE 0                               -- []
    ///     WHERE NULL                            -- []
    ///     WHERE id IS NULL                      -- []
    ///     WHERE id = 1                          -- [1]
    ///     WHERE id = 1 AND b = 2                -- [1]
    ///     WHERE id = 1 OR id = 2                -- [1, 2]
    ///     WHERE id IN (1, 2, 3)                 -- [1, 2, 3]
    ///     WHERE id IN (1, 2) OR rowid IN (2, 3) -- [1, 2, 3]
    ///     WHERE id > 1                          -- nil
    ///
    /// This method makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>?
    
    /// Performs a boolean test.
    ///
    /// We generally distinguish four boolean values:
    ///
    /// 1. truthy: `filter(expression)`
    /// 2. falsey: `filter(!expression)`
    /// 3. true: `filter(expression == true)`
    /// 4. false: `filter(expression == false)`
    ///
    /// They generally produce the following SQL:
    ///
    /// 1. truthy: `WHERE expression`
    /// 2. falsey: `WHERE NOT expression`
    /// 3. true: `WHERE expression = 1`
    /// 4. false: `WHERE expression = 0`
    ///
    /// The `= 1` and `= 0` tests allow the SQLite query planner to
    /// optimize queries with indices on boolean columns and expressions.
    /// See https://github.com/groue/GRDB.swift/issues/816
    ///
    /// This method is a customization point, so that some specific expressions
    /// can produce idiomatic SQL.
    ///
    /// For example, the `like(_)` expression:
    ///
    /// - `column.like(pattern)` -> `column LIKE pattern`
    /// - `!(column.like(pattern))` -> `column NOT LIKE pattern`
    /// - `column.like(pattern) == true` -> `(column LIKE pattern) = 1`
    /// - `column.like(pattern) == false` -> `(column LIKE pattern) = 0`
    ///
    /// Another example, the `isEmpty` association aggregate:
    ///
    /// - `association.isEmpty` -> `COUNT(child.id) = 0`
    /// - `!association.isEmpty` -> `COUNT(child.id) > 0`
    /// - `association.isEmpty == true` -> `COUNT(child.id) = 0`
    /// - `association.isEmpty == false` -> `COUNT(child.id) > 0`
    func _is(_ test: _SQLBooleanTest) -> SQLExpression
    
    /// Returns true if the expression has a unique value when SQLite runs
    /// a request.
    ///
    /// When in doubt, returns false.
    ///
    ///     1          -- true
    ///     1 + 2      -- true
    ///     score      -- false
    ///
    /// This property supports `_identifyingColums(_:for:)`
    var _isConstantInRequest: Bool { get }
    
    /// Returns true iff the expression is trivially true.
    ///
    /// When in doubt, returns false.
    ///
    /// This property helps clearing up the ON clause.
    var _isTrue: Bool { get }
    
    /// Returns a qualified expression
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression
}

extension _SQLExpression {
    /// If this expression is a table colum, returns the name of this column.
    ///
    /// When in doubt, returns nil.
    func _column(_ db: Database, for alias: TableAlias) throws -> String? {
        try _column(db, for: alias, acceptsBijection: false)
    }
}

/// SQLExpression is the protocol for types that represent an SQL expression, as
/// described at https://www.sqlite.org/lang_expr.html
public protocol SQLExpression: _SQLExpression, SQLSpecificExpressible, SQLSelectable, SQLOrderingTerm { }

/// `_SQLBooleanTest` supports boolean tests.
///
/// See `SQLExpression._is(_:)`
///
/// :nodoc:
public enum _SQLBooleanTest {
    /// Fuels `expression == true`
    case `true`
    
    /// Fuels `expression == false`
    case `false`
    
    /// Fuels `!expression`
    case falsey
}

extension SQLExpression {
    /// Returns self
    public var sqlExpression: SQLExpression { self }
    
    // MARK: _SQLExpression
    
    /// :nodoc:
    public func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        nil
    }
    
    /// :nodoc:
    public func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        []
    }
    
    /// :nodoc:
    public func _identifyingRowIDs(_ db: Database, for alias: TableAlias) throws -> Set<Int64>? {
        nil
    }
    
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return SQLExpressionNot(self)
        }
    }
    
    /// :nodoc:
    public var _isConstantInRequest: Bool { false }
    
    /// :nodoc:
    public var _isTrue: Bool { false }
    
    // MARK: SQLOrderingTerm
    
    /// :nodoc:
    public func _orderingTermSQL(_ context: SQLGenerationContext) throws -> String {
        try _expressionSQL(context, wrappedInParenthesis: false)
    }
    
    /// :nodoc:
    public func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        _qualifiedExpression(with: alias)
    }
    
    /// :nodoc:
    public var _reversed: SQLOrderingTerm { desc }
    
    // MARK: SQLSelectable
    
    /// :nodoc:
    public func _columnCount(_ db: Database) throws -> Int { 1 }
    
    /// :nodoc:
    public func _count(distinct: Bool) -> _SQLCount? {
        if distinct {
            // SELECT DISTINCT expr FROM tableName ...
            // ->
            // SELECT COUNT(DISTINCT expr) FROM tableName ...
            return .distinct(self)
        } else {
            // SELECT expr FROM tableName ...
            // ->
            // SELECT COUNT(*) FROM tableName ...
            return .all
        }
    }
    
    /// :nodoc:
    public func _countedSQL(_ context: SQLGenerationContext) throws -> String {
        try _expressionSQL(context, wrappedInParenthesis: false)
    }
    
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        _qualifiedExpression(with: alias)
    }
    
    /// :nodoc:
    public func _resultColumnSQL(_ context: SQLGenerationContext) throws -> String {
        try _expressionSQL(context, wrappedInParenthesis: false)
    }
}
