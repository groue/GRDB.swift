// MARK: - ABS(...)

/// Returns an expression that evaluates the `ABS` SQL function.
///
///     // ABS(amount)
///     abs(Column("amount"))
public func abs(_ value: SQLSpecificExpressible) -> SQLExpression {
    .function("ABS", [value.sqlExpression])
}


// MARK: - AVG(...)

/// Returns an expression that evaluates the `AVG` SQL function.
///
///     // AVG(length)
///     average(Column("length"))
public func average(_ value: SQLSpecificExpressible) -> SQLExpression {
    .aggregate("AVG", [value.sqlExpression])
}


// MARK: - COUNT(...)

// TODO: deprecate, replace with count(expression)
/// Returns an expression that evaluates the `COUNT` SQL function.
///
///     // COUNT(email)
///     count(Column("email"))
public func count(_ counted: SQLSelectable) -> SQLExpression {
    counted.sqlSelection.countExpression
}


// MARK: - COUNT(DISTINCT ...)

/// Returns an expression that evaluates the `COUNT(DISTINCT)` SQL function.
///
///     // COUNT(DISTINCT email)
///     count(distinct: Column("email"))
public func count(distinct value: SQLSpecificExpressible) -> SQLExpression {
    .countDistinct(value.sqlExpression)
}


// MARK: - IFNULL(...)

/// Returns an expression that evaluates the `IFNULL` SQL function.
///
///     // IFNULL(name, 'Anonymous')
///     Column("name") ?? "Anonymous"
public func ?? (lhs: SQLSpecificExpressible, rhs: SQLExpressible) -> SQLExpression {
    .function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
}


// MARK: - LENGTH(...)

/// Returns an expression that evaluates the `LENGTH` SQL function.
///
///     // LENGTH(name)
///     length(Column("name"))
public func length(_ value: SQLSpecificExpressible) -> SQLExpression {
    .function("LENGTH", [value.sqlExpression])
}


// MARK: - MAX(...)

/// Returns an expression that evaluates the `MAX` SQL function.
///
///     // MAX(score)
///     max(Column("score"))
public func max(_ value: SQLSpecificExpressible) -> SQLExpression {
    .aggregate("MAX", [value.sqlExpression])
}


// MARK: - MIN(...)

/// Returns an expression that evaluates the `MIN` SQL function.
///
///     // MIN(score)
///     min(Column("score"))
public func min(_ value: SQLSpecificExpressible) -> SQLExpression {
    .aggregate("MIN", [value.sqlExpression])
}


// MARK: - SUM(...)

/// Returns an expression that evaluates the `SUM` SQL function.
///
///     // SUM(amount)
///     sum(Column("amount"))
public func sum(_ value: SQLSpecificExpressible) -> SQLExpression {
    .aggregate("SUM", [value.sqlExpression])
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

/// A date modifier for SQLite date functions such as `julianDay(_:_:)` and
/// `dateTime(_:_:)`.
///
/// For more information, see https://www.sqlite.org/lang_datefunc.html
public enum SQLDateModifier: SQLSpecificExpressible {
    /// Adds the specified amount of seconds
    case second(Double)
    
    /// Adds the specified amount of minutes
    case minute(Int)
    
    /// Adds the specified amount of hours
    case hour(Int)
    
    /// Adds the specified amount of days
    case day(Int)
    
    /// Adds the specified amount of months
    case month(Int)
    
    /// Adds the specified amount of years
    case year(Int)
    
    /// Shifts the date backwards to the beginning of the current day
    case startOfDay
    
    /// Shifts the date backwards to the beginning of the current month
    case startOfMonth
    
    /// Shifts the date backwards to the beginning of the current year
    case startOfYear
    
    /// See https://www.sqlite.org/lang_datefunc.html
    case weekday(Int)
    
    /// See https://www.sqlite.org/lang_datefunc.html
    case unixEpoch
    
    /// See https://www.sqlite.org/lang_datefunc.html
    case localTime
    
    /// See https://www.sqlite.org/lang_datefunc.html
    case utc
    
    public var sqlExpression: SQLExpression {
        rawValue.sqlExpression
    }
    
    var rawValue: String {
        switch self {
        case let .day(value):
            return "\(value) days"
        case let .hour(value):
            return "\(value) hours"
        case let .minute(value):
            return "\(value) minutes"
        case let .second(value):
            return "\(value) seconds"
        case let .month(value):
            return "\(value) months"
        case let .year(value):
            return "\(value) years"
        case .startOfMonth:
            return "start of month"
        case .startOfYear:
            return "start of year"
        case .startOfDay:
            return "start of day"
        case let .weekday(value):
            return "weekday \(value)"
        case .unixEpoch:
            return "unixepoch"
        case .localTime:
            return "localtime"
        case .utc:
            return "utc"
        }
    }
}

// MARK: JULIANDAY(...)

/// Returns an expression that evaluates the `JULIANDAY` SQL function.
///
///     // JULIANDAY(date)
///     julianDay(Column("date"))
///
///     // JULIANDAY(date, '1 days')
///     julianDay(Column("date"), .day(1))
///
/// For more information, see https://www.sqlite.org/lang_datefunc.html
public func julianDay(_ value: SQLSpecificExpressible, _ modifiers: SQLDateModifier...) -> SQLExpression {
    .function("JULIANDAY", [value.sqlExpression] + modifiers.map(\.sqlExpression))
}

// MARK: DATETIME(...)

/// Returns an expression that evaluates the `DATETIME` SQL function.
///
///     // DATETIME(date)
///     dateTime(Column("date"))
///
///     // DATETIME(date, '1 days')
///     dateTime(Column("date"), .day(1))
///
/// For more information, see https://www.sqlite.org/lang_datefunc.html
public func dateTime(_ value: SQLSpecificExpressible, _ modifiers: SQLDateModifier...) -> SQLExpression {
    .function("DATETIME", [value.sqlExpression] + modifiers.map(\.sqlExpression))
}
