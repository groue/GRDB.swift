// MARK: - Custom Functions

extension DatabaseFunction {
    /// Returns an SQL expression that applies the function.
    ///
    /// See https://github.com/groue/GRDB.swift/#sql-functions
    public func callAsFunction(_ arguments: SQLExpressible...) -> SQLExpression {
        SQLExpressionFunction(SQLFunctionName(name), arguments: arguments.map(\.sqlExpression))
    }
}


// MARK: - ABS(...)

extension SQLFunctionName {
    /// The `ABS` function name
    public static let abs = SQLFunctionName("ABS")
}

/// Returns an expression that evaluates the `ABS` SQL function.
///
///     // ABS(amount)
///     abs(Column("amount"))
public func abs(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.abs, arguments: value)
}


// MARK: - AVG(...)

extension SQLFunctionName {
    /// The `AVG` function name
    public static let avg = SQLFunctionName("AVG")
}

/// Returns an expression that evaluates the `AVG` SQL function.
///
///     // AVG(length)
///     average(Column("length"))
public func average(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.avg, arguments: value)
}


// MARK: - COUNT(...)

/// Returns an expression that evaluates the `COUNT` SQL function.
///
///     // COUNT(email)
///     count(Column("email"))
public func count(_ counted: SQLSelectable) -> SQLExpression {
    SQLExpressionCount(counted)
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an expression that evaluates the `COUNT(DISTINCT)` SQL function.
///
///     // COUNT(DISTINCT email)
///     count(distinct: Column("email"))
public func count(distinct value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionCountDistinct(value.sqlExpression)
}


// MARK: - IFNULL(...)

extension SQLFunctionName {
    /// The `IFNULL` function name
    public static let ifNull = SQLFunctionName("IFNULL")
}

/// Returns an expression that evaluates the `IFNULL` SQL function.
///
///     // IFNULL(name, 'Anonymous')
///     Column("name") ?? "Anonymous"
public func ?? (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    SQLExpressionFunction(.ifNull, arguments: lhs, rhs)
}


// MARK: - LENGTH(...)

extension SQLFunctionName {
    /// The `LENGTH` function name
    public static let length = SQLFunctionName("LENGTH")
}

/// Returns an expression that evaluates the `LENGTH` SQL function.
///
///     // LENGTH(name)
///     length(Column("name"))
public func length(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.length, arguments: value)
}


// MARK: - MAX(...)

extension SQLFunctionName {
    /// The `MAX` function name
    public static let max = SQLFunctionName("MAX")
}

/// Returns an expression that evaluates the `MAX` SQL function.
///
///     // MAX(score)
///     max(Column("score"))
public func max(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.max, arguments: value)
}


// MARK: - MIN(...)

extension SQLFunctionName {
    /// The `MIN` function name
    public static let min = SQLFunctionName("MIN")
}

/// Returns an expression that evaluates the `MIN` SQL function.
///
///     // MIN(score)
///     min(Column("score"))
public func min(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.min, arguments: value)
}


// MARK: - SUM(...)

extension SQLFunctionName {
    /// The `SUM` function name
    public static let sum = SQLFunctionName("SUM")
}

/// Returns an expression that evaluates the `SUM` SQL function.
///
///     // SUM(amount)
///     sum(Column("amount"))
public func sum(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.sum, arguments: value)
}


// MARK: - String functions

/// :nodoc:
extension SQLSpecificExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// capitalized String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.capitalized)
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    public var capitalized: SQLExpression {
        DatabaseFunction.capitalize(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// lowercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.lowercased())
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    public var lowercased: SQLExpression {
        DatabaseFunction.lowercase(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// uppercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.uppercased())
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    public var uppercased: SQLExpression {
        DatabaseFunction.uppercase(sqlExpression)
    }
}

/// :nodoc:
extension SQLSpecificExpressible {
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedCapitalized String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.localizedCapitalized)
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    @available(OSX 10.11, watchOS 3.0, *)
    public var localizedCapitalized: SQLExpression {
        DatabaseFunction.localizedCapitalize(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedLowercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.localizedLowercased)
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    @available(OSX 10.11, watchOS 3.0, *)
    public var localizedLowercased: SQLExpression {
        DatabaseFunction.localizedLowercase(sqlExpression)
    }
    
    /// Returns an SQL expression that applies the Swift's built-in
    /// localizedUppercased String property. It is NULL for non-String arguments.
    ///
    ///     let nameColumn = Column("name")
    ///     let request = Player.select(nameColumn.localizedUppercased)
    ///     let names = try String.fetchAll(dbQueue, request)   // [String]
    @available(OSX 10.11, watchOS 3.0, *)
    public var localizedUppercased: SQLExpression {
        DatabaseFunction.localizedUppercase(sqlExpression)
    }
}

// MARK: - Date functions

// MARK: JULIANDAY(...)

extension SQLFunctionName {
    /// The `JULIANDAY` function name
    public static let julianDay = SQLFunctionName("JULIANDAY")
}

/// Returns an expression that evaluates the `JULIANDAY` SQL function.
///
///     // JULIANDAY(date)
///     julianDay(Column("date"))
public func julianDay(_ value: SQLSpecificExpressible) -> SQLExpression {
    SQLExpressionFunction(.julianDay, arguments: value)
}
