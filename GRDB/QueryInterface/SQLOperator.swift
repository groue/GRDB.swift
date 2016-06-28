// MARK: - Operator =

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: protocol<_SQLExpressible, BooleanType>?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs.boolValue {
            return lhs.sqlExpression
        } else {
            return .Not(lhs.sqlExpression)
        }
    } else {
        return .Equal(lhs.sqlExpression, .Value(nil))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Equal(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: protocol<_SQLExpressible, BooleanType>?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs.boolValue {
            return rhs.sqlExpression
        } else {
            return .Not(rhs.sqlExpression)
        }
    } else {
        return .Equal(.Value(nil), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Equal(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator !=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: protocol<_SQLExpressible, BooleanType>?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs.boolValue {
            return .Not(lhs.sqlExpression)
        } else {
            return lhs.sqlExpression
        }
    } else {
        return .NotEqual(lhs.sqlExpression, .Value(nil))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .NotEqual(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: protocol<_SQLExpressible, BooleanType>?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs.boolValue {
            return .Not(rhs.sqlExpression)
        } else {
            return rhs.sqlExpression
        }
    } else {
        return .NotEqual(.Value(nil), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .NotEqual(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator *

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator /

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator +

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator - (prefix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func - (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .PrefixOperator("-", value.sqlExpression)
}


// MARK: - Operator - (infix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator AND

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator BETWEEN

extension Range where Element: protocol<_SQLExpressible, BidirectionalIndexType> {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: startIndex.sqlExpression, max: endIndex.predecessor().sqlExpression)
    }
}

extension ClosedInterval where Bound: _SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .Between(value: element.sqlExpression, min: start.sqlExpression, max: end.sqlExpression)
    }
}

extension HalfOpenInterval where Bound: _SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: - Operator IN

extension SequenceType where Self.Generator.Element: _SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SpecificSQLExpressible) -> _SQLExpression {
        return .In(map { $0.sqlExpression }, element.sqlExpression)
    }
}


// MARK: - Operator IS

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Is(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .Is(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator IS NOT

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs?.sqlExpression ?? .Value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .IsNot(lhs?.sqlExpression ?? .Value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .IsNot(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator OR

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .InfixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator NOT

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func ! (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Not(value.sqlExpression)
}
