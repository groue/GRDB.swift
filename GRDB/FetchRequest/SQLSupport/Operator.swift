// MARK: - Operator =

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Equal(lhs.SQLExpression, rhs?.SQLExpression ?? .Value(nil))
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressionType?, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .Equal(lhs?.SQLExpression ?? .Value(nil), rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .Equal(lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator !=

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .NotEqual(lhs.SQLExpression, rhs?.SQLExpression ?? .Value(nil))
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressionType?, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .NotEqual(lhs?.SQLExpression ?? .Value(nil), rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .NotEqual(lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator <

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator <=

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("<=", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator >

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator >=

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator(">=", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator *

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("*", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator /

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("/", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator +

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("+", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator - (prefix)

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func - (value: _DerivedSQLExpressionType) -> _SQLExpression {
    return .PrefixOperator("-", value.SQLExpression)
}


// MARK: - Operator - (infix)

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("-", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator AND

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("AND", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator BETWEEN

extension Range where Element: protocol<_SQLExpressionType, BidirectionalIndexType> {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _DerivedSQLExpressionType) -> _SQLExpression {
        return .Between(value: element.SQLExpression, min: startIndex.SQLExpression, max: endIndex.predecessor().SQLExpression)
    }
}

extension ClosedInterval where Bound: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _DerivedSQLExpressionType) -> _SQLExpression {
        return .Between(value: element.SQLExpression, min: start.SQLExpression, max: end.SQLExpression)
    }
}

extension HalfOpenInterval where Bound: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _DerivedSQLExpressionType) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: - Operator IN

extension SequenceType where Self.Generator.Element: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _DerivedSQLExpressionType) -> _SQLExpression {
        return .In(map { $0.SQLExpression }, element.SQLExpression)
    }
}


// MARK: - Operator IS

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Is(lhs.SQLExpression, rhs?.SQLExpression ?? .Value(nil))
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressionType?, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .Is(lhs?.SQLExpression ?? .Value(nil), rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .Is(lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator IS NOT

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .IsNot(lhs.SQLExpression, rhs?.SQLExpression ?? .Value(nil))
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressionType?, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .IsNot(lhs?.SQLExpression ?? .Value(nil), rhs.SQLExpression)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .IsNot(lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator OR

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _DerivedSQLExpressionType, rhs: _SQLExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.SQLExpression, rhs.SQLExpression)
}

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _DerivedSQLExpressionType, rhs: _DerivedSQLExpressionType) -> _SQLExpression {
    return .InfixOperator("OR", lhs.SQLExpression, rhs.SQLExpression)
}


// MARK: - Operator NOT

/// Returns a SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func ! (value: _DerivedSQLExpressionType) -> _SQLExpression {
    return .Not(value.SQLExpression)
}
