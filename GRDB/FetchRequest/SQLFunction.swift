// MARK: - Custom Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func apply(_ arguments: _SQLExpressible...) -> _SQLExpression {
        return .function(name, arguments.map { $0.sqlExpression })
    }
}


// MARK: - ABS(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func abs(_ value: _SpecificSQLExpressible) -> _SQLExpression {
    return .function("ABS", [value.sqlExpression])
}


// MARK: - AVG(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func average(_ value: _SpecificSQLExpressible) -> _SQLExpression {
    return .function("AVG", [value.sqlExpression])
}


// MARK: - COUNT(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(_ counted: _SpecificSQLExpressible) -> _SQLExpression {
    return .count(counted)
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func count(distinct value: _SpecificSQLExpressible) -> _SQLExpression {
    return .countDistinct(value.sqlExpression)
}


// MARK: - IFNULL(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SpecificSQLExpressible, rhs: _SQLExpressible) -> _SQLExpression {
    return .function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
}

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func ?? (lhs: _SQLExpressible?, rhs: _SpecificSQLExpressible) -> _SQLExpression {
    if let lhs = lhs {
        return .function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
    } else {
        return rhs.sqlExpression
    }
}


// MARK: - MAX(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func max(_ value: _SpecificSQLExpressible) -> _SQLExpression {
    return .function("MAX", [value.sqlExpression])
}


// MARK: - MIN(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func min(_ value: _SpecificSQLExpressible) -> _SQLExpression {
    return .function("MIN", [value.sqlExpression])
}


// MARK: - SUM(...)

/// Returns an SQL expression.
///
/// See https://github.com/groue/GRDB.swift/#sql-functions
public func sum(_ value: _SpecificSQLExpressible) -> _SQLExpression {
    return .function("SUM", [value.sqlExpression])
}


// MARK: - Swift String functions

extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// capitalized String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.capitalized)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var capitalized: _SQLExpression {
        return DatabaseFunction.capitalize.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// lowercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.lowercased())
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var lowercased: _SQLExpression {
        return DatabaseFunction.lowercase.apply(sqlExpression)
    }

    /// Returns an SQL expression that applies the Swift's built-in
    /// uppercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.uppercased())
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var uppercased: _SQLExpression {
        return DatabaseFunction.uppercase.apply(sqlExpression)
    }
}

@available(iOS 9.0, OSX 10.11, *)
extension _SpecificSQLExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedCapitalized String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedCapitalized)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedCapitalized: _SQLExpression {
        return DatabaseFunction.localizedCapitalize.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedLowercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedLowercased)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedLowercased: _SQLExpression {
        return DatabaseFunction.localizedLowercase.apply(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedUppercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = SQLColumn("name")
    ///     let request = Person.select(nameColumn.localizedUppercased)
    ///     let names = String.fetchAll(dbQueue, request)   // [String]
    public var localizedUppercased: _SQLExpression {
        return DatabaseFunction.localizedUppercase.apply(sqlExpression)
    }
}
