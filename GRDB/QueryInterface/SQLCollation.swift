/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct _SQLCollatedExpression {
    let baseExpression: _SQLExpression
    let collationName: String
}

extension _SQLCollatedExpression : _SQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .collate(baseExpression, collationName)
    }
}

extension _SQLCollatedExpression : _SQLOrderable {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedOrdering: _SQLOrderingExpression {
        return .desc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLOrderingExpression {
        return .asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLOrderingExpression {
        return .desc(sqlExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.orderingSQL(&arguments)
    }
}

extension _SpecificSQLExpressible {
    
    public func collating(_ collationName: String) -> _SQLCollatedExpression {
        return _SQLCollatedExpression(baseExpression: sqlExpression, collationName: collationName)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(_ collation: SQLCollation) -> _SQLCollatedExpression {
        return collating(collation.rawValue)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(_ collation: DatabaseCollation) -> _SQLCollatedExpression {
        return collating(collation.name)
    }
}


// MARK: - Operator = COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLCollatedExpression, rhs: _SQLExpressible?) -> _SQLExpression {
    return .collate(lhs.baseExpression == rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator != COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLCollatedExpression, rhs: _SQLExpressible?) -> _SQLExpression {
    return .collate(lhs.baseExpression != rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs != rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator < COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLCollatedExpression, rhs: _SQLExpressible) -> _SQLExpression {
    return .collate(lhs.baseExpression < rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs < rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator <= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLCollatedExpression, rhs: _SQLExpressible) -> _SQLExpression {
    return .collate(lhs.baseExpression <= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs <= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator > COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLCollatedExpression, rhs: _SQLExpressible) -> _SQLExpression {
    return .collate(lhs.baseExpression > rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs > rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator >= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLCollatedExpression, rhs: _SQLExpressible) -> _SQLExpression {
    return .collate(lhs.baseExpression >= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs >= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator BETWEEN COLLATE

extension Range where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SQLCollatedExpression) -> _SQLExpression {
        return (element >= lowerBound) && (element < upperBound)
    }
}

extension ClosedRange where Bound: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a range.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SQLCollatedExpression) -> _SQLExpression {
        return .collate(contains(element.baseExpression), element.collationName)
    }
}


// MARK: - Operator IN COLLATE

extension Sequence where Self.Iterator.Element: _SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(_ element: _SQLCollatedExpression) -> _SQLExpression {
        return .collate(contains(element.baseExpression), element.collationName)
    }
}


// MARK: - Operator IS COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLCollatedExpression, rhs: _SQLExpressible?) -> _SQLExpression {
    return .collate(lhs.baseExpression === rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator IS NOT COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLCollatedExpression, rhs: _SQLExpressible?) -> _SQLExpression {
    return .collate(lhs.baseExpression !== rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .collate(lhs !== rhs.baseExpression, rhs.collationName)
}
