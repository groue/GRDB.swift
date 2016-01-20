// MARK: - Custom Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func apply(arguments: _SQLExpressionType...) -> _DerivedSQLExpressionType {
        return _SQLExpression.Function(name, arguments.map { $0.SQLExpression })
    }
}


// MARK: - ABS(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func abs(value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("ABS", [value.SQLExpression])
}


// MARK: - AVG(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func average(value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("AVG", [value.SQLExpression])
}


// MARK: - COUNT(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(counted: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Count(counted)
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(distinct value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.CountDistinct(value.SQLExpression)
}


// MARK: - IFNULL(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("IFNULL", [lhs.SQLExpression, rhs.SQLExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SQLExpressionType?, rhs: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    if let lhs = lhs {
        return _SQLExpression.Function("IFNULL", [lhs.SQLExpression, rhs.SQLExpression])
    } else {
        return rhs.SQLExpression
    }
}


// MARK: - LOWER(...)

extension _DerivedSQLExpressionType {
    /// Returns an SQL expression.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public var lowercaseString: _DerivedSQLExpressionType {
        return _SQLExpression.Function("LOWER", [SQLExpression])
    }
}


// MARK: - MAX(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func max(value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("MAX", [value.SQLExpression])
}


// MARK: - MIN(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func min(value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("MIN", [value.SQLExpression])
}


// MARK: - SUM(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func sum(value: _DerivedSQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Function("SUM", [value.SQLExpression])
}


// MARK: - UPPER(...)

extension _DerivedSQLExpressionType {
    /// Returns an SQL expression.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public var uppercaseString: _DerivedSQLExpressionType {
        return _SQLExpression.Function("UPPER", [SQLExpression])
    }
}
