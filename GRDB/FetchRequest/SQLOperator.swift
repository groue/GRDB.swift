// MARK: - Operator =

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Equal(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator !=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .NotEqual(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator *

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator /

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator +

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator - (prefix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func - (value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .PrefixOperator("-", value.sqlExpression)
}


// MARK: - Operator - (infix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator AND

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator BETWEEN

extension Range where Element: protocol<_SQLExpressionType, BidirectionalIndexType> {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLDerivedExpressionType) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: startIndex.sqlExpression, max: endIndex.predecessor().sqlExpression)
    }
}

extension ClosedInterval where Bound: _SQLExpressionType {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLDerivedExpressionType) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: start.sqlExpression, max: end.sqlExpression)
    }
}

extension HalfOpenInterval where Bound: _SQLExpressionType {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLDerivedExpressionType) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: - Operator IN

extension SequenceType where Self.Generator.Element: _SQLExpressionType {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLDerivedExpressionType) -> _SQLExpression {
        return .In(map { $0.sqlExpression }, element.sqlExpression)
    }
}


// MARK: - Operator IS

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Is(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator IS NOT

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressionType?, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .IsNot(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator OR

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLDerivedExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLDerivedExpressionType, rhs: _SQLDerivedExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator NOT

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func ! (value: _SQLDerivedExpressionType) -> _SQLExpression {
    return .Not(value.sqlExpression)
}
