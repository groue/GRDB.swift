/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct _SQLCollatedExpression {
    let baseExpression: _SQLExpression
    let collationName: String
}

extension _SQLCollatedExpression : SQLExpressible {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var sqlExpression: _SQLExpression {
        return .Collate(baseExpression, collationName)
    }
}

extension _SQLCollatedExpression : _SQLOrdering {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedSortDescriptor: _SQLSortDescriptor {
        return .Desc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLSortDescriptor {
        return .Asc(sqlExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLSortDescriptor {
        return .Desc(sqlExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(inout arguments: StatementArguments?) -> String {
        return sqlExpression.orderingSQL(&arguments)
    }
}

extension _SpecificSQLExpressible {
    
    func collating(collationName: String) -> _SQLCollatedExpression {
        return _SQLCollatedExpression(baseExpression: sqlExpression, collationName: collationName)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(collation: SQLCollation) -> _SQLCollatedExpression {
        return collating(collation.rawValue)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(collation: DatabaseCollation) -> _SQLCollatedExpression {
        return collating(collation.name)
    }
}


// MARK: - Operator = COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLCollatedExpression, rhs: SQLExpressible?) -> _SQLExpression {
    return .Collate(lhs.baseExpression == rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator != COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLCollatedExpression, rhs: SQLExpressible?) -> _SQLExpression {
    return .Collate(lhs.baseExpression != rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs != rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator < COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLCollatedExpression, rhs: SQLExpressible) -> _SQLExpression {
    return .Collate(lhs.baseExpression < rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs < rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator <= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLCollatedExpression, rhs: SQLExpressible) -> _SQLExpression {
    return .Collate(lhs.baseExpression <= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs <= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator > COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLCollatedExpression, rhs: SQLExpressible) -> _SQLExpression {
    return .Collate(lhs.baseExpression > rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs > rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator >= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLCollatedExpression, rhs: SQLExpressible) -> _SQLExpression {
    return .Collate(lhs.baseExpression >= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: SQLExpressible, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs >= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator BETWEEN COLLATE

extension ClosedInterval where Bound: SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLCollatedExpression) -> _SQLExpression {
        return .Collate(contains(element.baseExpression), element.collationName)
    }
}

extension HalfOpenInterval where Bound: SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLCollatedExpression) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: - Operator IN COLLATE

extension SequenceType where Self.Generator.Element: SQLExpressible {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _SQLCollatedExpression) -> _SQLExpression {
        return .Collate(contains(element.baseExpression), element.collationName)
    }
}


// MARK: - Operator IS COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLCollatedExpression, rhs: SQLExpressible?) -> _SQLExpression {
    return .Collate(lhs.baseExpression === rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator IS NOT COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLCollatedExpression, rhs: SQLExpressible?) -> _SQLExpression {
    return .Collate(lhs.baseExpression !== rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: SQLExpressible?, rhs: _SQLCollatedExpression) -> _SQLExpression {
    return .Collate(lhs !== rhs.baseExpression, rhs.collationName)
}
