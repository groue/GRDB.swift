// MARK: - Operator =

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .equalOperator(lhs.sqlExpression, rhs?.sqlExpression ?? .value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: Bool?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs {
            return lhs.sqlExpression
        } else {
            return .notOperator(lhs.sqlExpression)
        }
    } else {
        return .equalOperator(lhs.sqlExpression, .value(nil))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .equalOperator(lhs?.sqlExpression ?? .value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: Bool?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs {
            return rhs.sqlExpression
        } else {
            return .notOperator(rhs.sqlExpression)
        }
    } else {
        return .equalOperator(.value(nil), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .equalOperator(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator !=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .notEqualOperator(lhs.sqlExpression, rhs?.sqlExpression ?? .value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: Bool?) -> _SQLExpression {
    if let rhs = rhs {
        if rhs {
            return .notOperator(lhs.sqlExpression)
        } else {
            return lhs.sqlExpression
        }
    } else {
        return .notEqualOperator(lhs.sqlExpression, .value(nil))
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .notEqualOperator(lhs?.sqlExpression ?? .value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: Bool?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        if lhs {
            return .notOperator(rhs.sqlExpression)
        } else {
            return rhs.sqlExpression
        }
    } else {
        return .notEqualOperator(.value(nil), rhs.sqlExpression)
    }
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .notEqualOperator(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("<", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator <=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("<=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator(">", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator >=

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator(">=", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator *

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func * (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("*", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator /

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func / (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("/", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator +

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func + (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("+", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator - (prefix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func - (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .prefixOperator("-", value.sqlExpression)
}


// MARK: - Operator - (infix)

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL arithmetic expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func - (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("-", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator AND

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func && (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("AND", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator BETWEEN

extension Range where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SpecificSQLExpressible) -> _SQLExpression {
        return (element >= lowerBound) && (element < upperBound)
    }
}

extension ClosedRange where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SpecificSQLExpressible) -> _SQLExpression {
        return .between(value: element.sqlExpression, min: lowerBound.sqlExpression, max: upperBound.sqlExpression)
    }
}

extension CountableRange where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SpecificSQLExpressible) -> _SQLExpression {
        return .between(value: element.sqlExpression, min: lowerBound.sqlExpression, max: upperBound.advanced(by: -1).sqlExpression)
    }
}

extension CountableClosedRange where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SpecificSQLExpressible) -> _SQLExpression {
        return .between(value: element.sqlExpression, min: lowerBound.sqlExpression, max: upperBound.sqlExpression)
    }
}


// MARK: - Operator IN

extension Sequence where Self.Iterator.Element: _SQLExpressible {
    /// Returns an SQL expression that checks the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SpecificSQLExpressible) -> _SQLExpression {
        return .inOperator(map { $0.sqlExpression }, element.sqlExpression)
    }
}


// MARK: - Operator IS

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .isOperator(lhs.sqlExpression, rhs?.sqlExpression ?? .value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .isOperator(lhs?.sqlExpression ?? .value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .isOperator(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator IS NOT

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible?) -> _SQLExpression {
    return .isNotOperator(lhs.sqlExpression, rhs?.sqlExpression ?? .value(nil))
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .isNotOperator(lhs?.sqlExpression ?? .value(nil), rhs.sqlExpression)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .isNotOperator(lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator OR

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .infixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func || (lhs: _SpecificSQLExpressible, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    return .infixOperator("OR", lhs.sqlExpression, rhs.sqlExpression)
}


// MARK: - Operator NOT

/// Returns an SQL logical expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public prefix func ! (value: _SpecificSQLExpressible) -> _SQLExpression {
    return .notOperator(value.sqlExpression)
}
