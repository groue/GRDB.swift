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
    public func orderingSQL(inout bindings: [DatabaseValueConvertible?]) throws -> String {
        return try SQLExpression.orderingSQL(&bindings)
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

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .Equal(
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func == (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .Equal(
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator != COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .NotEqual(
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func != (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .NotEqual(
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator < COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator("<",
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func < (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator("<",
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator <= COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator("<=",
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func <= (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator("<=",
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator > COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator(">",
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func > (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator(">",
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator >= COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator(">=",
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func >= (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .InfixOperator(">=",
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator BETWEEN COLLATE

extension ClosedInterval where Bound: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _DerivedSQLExpressionType {
        return _SQLExpression.Collate(
            .Between(
                value: element.baseExpression,
                min: start.SQLExpression,
                max: end.SQLExpression),
            element.collationName)
    }
}

extension HalfOpenInterval where Bound: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// an interval.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _DerivedSQLExpressionType {
        return _SQLExpression.InfixOperator("AND",
            .Collate(
                .InfixOperator(">=",
                    element.baseExpression,
                    start.SQLExpression),
                element.collationName),
            .Collate(
                .InfixOperator("<",
                    element.baseExpression,
                    end.SQLExpression),
                element.collationName))
    }
}


// MARK: - Operator IN COLLATE

extension SequenceType where Self.Generator.Element: _SQLExpressionType {
    /// Returns a SQL expression that compares the inclusion of a value in
    /// a sequence.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-operators
    public func contains(element: _CollatedExpression) -> _DerivedSQLExpressionType {
        return _SQLExpression.Collate(
            .In(
                map { $0.SQLExpression },
                element.baseExpression),
            element.collationName)
    }
}


// MARK: - Operator IS COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .Is(
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func === (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .Is(
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}


// MARK: - Operator IS NOT COLLATE

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _CollatedExpression, rhs: _SQLExpressionType) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .IsNot(
            lhs.baseExpression,
            rhs.SQLExpression),
        lhs.collationName)
}

/// Returns a SQL expression that compares two values.
///
/// See https://github.com/groue/GRDB.swift/#sql-operators
public func !== (lhs: _SQLExpressionType, rhs: _CollatedExpression) -> _DerivedSQLExpressionType {
    return _SQLExpression.Collate(
        .IsNot(
            lhs.SQLExpression,
            rhs.baseExpression),
        rhs.collationName)
}
