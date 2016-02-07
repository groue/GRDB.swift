/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
public struct _CollatedExpression {
    let baseExpression: _SQLExpression
    let collationName: String
}

extension _CollatedExpression : _SQLExpressionType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var SQLExpression: _SQLExpression {
        return .Collate(baseExpression, collationName)
    }
}

extension _CollatedExpression : _SQLSortDescriptorType {
    
    /// This property is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var reversedSortDescriptor: _SQLSortDescriptor {
        return .Desc(SQLExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var asc: _SQLSortDescriptorType {
        return _SQLSortDescriptor.Asc(SQLExpression)
    }
    
    /// Returns a value that can be used as an argument to FetchRequest.order()
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public var desc: _SQLSortDescriptorType {
        return _SQLSortDescriptor.Desc(SQLExpression)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func orderingSQL(db: Database, inout _ bindings: [DatabaseValueConvertible?]) throws -> String {
        return try SQLExpression.orderingSQL(db, &bindings)
    }
}

extension _DerivedSQLExpressionType {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(collationName: String) -> _CollatedExpression {
        return _CollatedExpression(baseExpression: SQLExpression, collationName: collationName)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    public func collating(collation: DatabaseCollation) -> _CollatedExpression {
        return collating(collation.name)
    }
}


// MARK: - Operator = COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _CollatedExpression, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Collate(lhs.baseExpression == rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressionType?, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator != COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _CollatedExpression, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Collate(lhs.baseExpression != rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressionType?, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs != rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator < COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _SQLExpression {
    return .Collate(lhs.baseExpression < rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs < rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator <= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _SQLExpression {
    return .Collate(lhs.baseExpression <= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs <= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator > COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _SQLExpression {
    return .Collate(lhs.baseExpression > rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs > rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator >= COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _SQLExpression {
    return .Collate(lhs.baseExpression >= rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs >= rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator BETWEEN COLLATE

extension ClosedInterval where Bound: _SQLExpressionType {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _SQLExpression {
        return .Collate(contains(element.baseExpression), element.collationName)
    }
}

extension HalfOpenInterval where Bound: _SQLExpressionType {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _SQLExpression {
        return (element >= start) && (element < end)
    }
}


// MARK: - Operator IN COLLATE

extension SequenceType where Self.Generator.Element: _SQLExpressionType {
    /// Returns an SQL expression that compares the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _SQLExpression {
        return .Collate(contains(element.baseExpression), element.collationName)
    }
}


// MARK: - Operator IS COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _CollatedExpression, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Collate(lhs.baseExpression === rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressionType?, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs == rhs.baseExpression, rhs.collationName)
}


// MARK: - Operator IS NOT COLLATE

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _CollatedExpression, rhs: _SQLExpressionType?) -> _SQLExpression {
    return .Collate(lhs.baseExpression !== rhs, lhs.collationName)
}

/// Returns an SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressionType?, rhs: _CollatedExpression) -> _SQLExpression {
    return .Collate(lhs !== rhs.baseExpression, rhs.collationName)
}
