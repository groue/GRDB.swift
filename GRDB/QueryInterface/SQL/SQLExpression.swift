// MARK: - SQLExpression

/// Implementation details of `SQLExpression`.
///
/// :nodoc:
public protocol _SQLExpression {
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
    /// The "true" and "false" tests allow the SQLite query planner to
    /// optimize indexed boolean columns. This is why it is important that the
    /// user can explicitly use them. See https://github.com/groue/GRDB.swift/issues/816
    ///
    /// This method is a customization point, so that some specific expressions
    /// can produce idiomatic SQL. For example:
    ///
    /// - `column.like(pattern` -> `column LIKE pattern`
    /// - `!(column.like(pattern)` -> `column NOT LIKE pattern`
    /// - `(column.like(pattern) == true` -> `column LIKE pattern`
    /// - `(column.like(pattern) == false` -> `column NOT LIKE pattern`
    func _is(_ test: _SQLBooleanTest) -> SQLExpression
    
    /// Returns a qualified expression
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression
    
    /// Accepts a visitor
    func _accept<Visitor: _SQLExpressionVisitor>(_ visitor: inout Visitor) throws
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
    /// The default implementation of boolean tests.
    ///
    /// :nodoc:
    public func _is(_ test: _SQLBooleanTest) -> SQLExpression {
        switch test {
        case .true:
            return _SQLExpressionEqual(.equal, self, true.sqlExpression)
            
        case .false:
            return _SQLExpressionEqual(.equal, self, false.sqlExpression)
            
        case .falsey:
            return _SQLExpressionNot(self)
        }
    }
}

extension SQLExpression {
    /// :nodoc:
    public func _qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        _qualifiedExpression(with: alias)
    }
    
    /// :nodoc:
    public func _qualifiedOrdering(with alias: TableAlias) -> SQLOrderingTerm {
        _qualifiedExpression(with: alias)
    }
}

// SQLExpression: SQLExpressible

extension SQLExpression {
    /// :nodoc:
    public var sqlExpression: SQLExpression {
        self
    }
}

// SQLExpression: SQLSelectable

extension SQLExpression {
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
}
