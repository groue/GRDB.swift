// MARK: - Custom Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func apply(arguments: _SQLExpressible...) -> _SQLExpression {
        return .Function(name, arguments.map { $0.sqlExpression })
    }
}


// MARK: - ABS(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func abs(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("ABS", [value.sqlExpression])
}


// MARK: - AVG(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func average(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("AVG", [value.sqlExpression])
}


// MARK: - COUNT(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(counted: _SQLSelectable) -> _SQLExpression {
    return .Count(counted)
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(distinct value: _SpecificSQLExpressible) -> _SQLExpression {
    return .CountDistinct(value.sqlExpression)
}


// MARK: - IFNULL(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        return .Function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
    } else {
        return rhs.sqlExpression
    }
}


// MARK: - MAX(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func max(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("MAX", [value.sqlExpression])
}


// MARK: - MIN(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func min(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("MIN", [value.sqlExpression])
}


// MARK: - SUM(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func sum(value: _SpecificSQLExpressible) -> _SQLExpression {
    return .Function("SUM", [value.sqlExpression])
}


// MARK: - Swift String functions

extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// capitalizedString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.capitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var capitalizedString: _SQLExpression {
        return DatabaseFunction.capitalizedString.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// lowercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.lowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var lowercaseString: _SQLExpression {
        return DatabaseFunction.lowercaseString.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// uppercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.uppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var uppercaseString: _SQLExpression {
        return DatabaseFunction.uppercaseString.apply(sqlExpression)
    }
}

@available(iOS 9.0, OSX 10.11, *)
extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedCapitalizedString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedCapitalizedString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedCapitalizedString: _SQLExpression {
        return DatabaseFunction.localizedCapitalizedString.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedLowercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedLowercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedLowercaseString: _SQLExpression {
        return DatabaseFunction.localizedLowercaseString.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedUppercaseString String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedUppercaseString)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedUppercaseString: _SQLExpression {
        return DatabaseFunction.localizedUppercaseString.apply(sqlExpression)
    }
}
