// MARK: - Custom Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func apply(arguments: _SQLExpressionType...) -> _SQLExpression {
        return .Function(name, arguments.map { $0.sqlExpression })
    }
}


// MARK: - ABS(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func abs(value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Function("ABS", [value.sqlExpression])
}


// MARK: - AVG(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func average(value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Function("AVG", [value.sqlExpression])
}


// MARK: - COUNT(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(counted: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Count(counted)
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(distinct value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .CountDistinct(value.sqlExpression)
}


// MARK: - IFNULL(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    if let lhs = lhs {
        return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
    } else {
        return rhs.sqlExpression
    }
}


// MARK: - LOWER(...)

extension _SQLDerivedExpressionType {
    /// Returns an SQL expression.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public var lowercaseString: _SQLExpression {
        return .Function("LOWER", [sqlExpression])
    }
}


// MARK: - MAX(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func max(value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Function("MAX", [value.sqlExpression])
}


// MARK: - MIN(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func min(value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Function("MIN", [value.sqlExpression])
}


// MARK: - SUM(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func sum(value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Function("SUM", [value.sqlExpression])
}


// MARK: - UPPER(...)

extension _SQLDerivedExpressionType {
    /// Returns an SQL expression.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public var uppercaseString: _SQLExpression {
        return .Function("UPPER", [sqlExpression])
    }
}
