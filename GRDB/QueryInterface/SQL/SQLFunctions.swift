/// The `ABS` SQL function.
///
/// For example:
///
/// ```swift
/// // ABS(amount)
/// abs(Column("amount"))
/// ```
public func abs(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .function("ABS", [value.sqlExpression])
}

/// The `AVG` SQL function.
///
/// For example:
///
/// ```swift
/// // AVG(length)
/// average(Column("length"))
/// ```
public func average(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregate("AVG", [value.sqlExpression])
}

/// The `COUNT` SQL function.
///
/// For example:
///
/// ```swift
/// // COUNT(email)
/// count(Column("email"))
/// ```
public func count(_ counted: some SQLSpecificExpressible) -> SQLExpression {
    .count(counted.sqlExpression)
}

/// The `COUNT(DISTINCT)` SQL function.
///
/// For example:
///
/// ```swift
/// // COUNT(DISTINCT email)
/// count(distinct: Column("email"))
/// ```
public func count(distinct value: some SQLSpecificExpressible) -> SQLExpression {
    .countDistinct(value.sqlExpression)
}

extension SQLSpecificExpressible {
    /// The `IFNULL` SQL function.
    ///
    /// For example:
    ///
    /// ```swift
    /// // IFNULL(name, 'Anonymous')
    /// Column("name") ?? "Anonymous"
    /// ```
    public static func ?? (lhs: Self, rhs: some SQLExpressible) -> SQLExpression {
        .function("IFNULL", [lhs.sqlExpression, rhs.sqlExpression])
    }
}

/// The `LENGTH` SQL function.
///
/// For example:
///
/// ```swift
/// // LENGTH(name)
/// length(Column("name"))
/// ```
public func length(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .function("LENGTH", [value.sqlExpression])
}

/// The `MAX` SQL function.
///
/// For example:
///
/// ```swift
/// // MAX(score)
/// max(Column("score"))
/// ```
public func max(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregate("MAX", [value.sqlExpression])
}

/// The `MIN` SQL function.
///
/// For example:
///
/// ```swift
/// // MIN(score)
/// min(Column("score"))
/// ```
public func min(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregate("MIN", [value.sqlExpression])
}

/// The `SUM` SQL function.
///
/// For example:
///
/// ```swift
/// // SUM(amount)
/// sum(Column("amount"))
/// ```
///
/// See also ``total(_:)``.
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
public func sum(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregate("SUM", [value.sqlExpression])
}

/// The `TOTAL` SQL function.
///
/// For example:
///
/// ```swift
/// // TOTAL(amount)
/// total(Column("amount"))
/// ```
///
/// See also ``sum(_:)``.
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
public func total(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregate("TOTAL", [value.sqlExpression])
}

// MARK: - String functions

extension SQLSpecificExpressible {
    /// An SQL expression that calls the Foundation
    /// `String.capitalized` property.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").capitalized
    /// ```
    public var capitalized: SQLExpression {
        DatabaseFunction.capitalize(sqlExpression)
    }
    
    /// An SQL expression that calls the Swift
    /// `String.lowercased()` method.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").lowercased
    /// ```
    public var lowercased: SQLExpression {
        DatabaseFunction.lowercase(sqlExpression)
    }
    
    /// An SQL expression that calls the Swift
    /// `String.uppercased()` method.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").uppercased
    /// ```
    public var uppercased: SQLExpression {
        DatabaseFunction.uppercase(sqlExpression)
    }
}

extension SQLSpecificExpressible {
    /// An SQL expression that calls the Foundation
    /// `String.localizedCapitalized` property.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").localizedCapitalized
    /// ```
    public var localizedCapitalized: SQLExpression {
        DatabaseFunction.localizedCapitalize(sqlExpression)
    }
    
    /// An SQL expression that calls the Foundation
    /// `String.localizedLowercase` property.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").localizedLowercased
    /// ```
    public var localizedLowercased: SQLExpression {
        DatabaseFunction.localizedLowercase(sqlExpression)
    }
    
    /// An SQL expression that calls the Foundation
    /// `String.localizedUppercase` property.
    ///
    /// For example:
    ///
    /// ```swift
    /// Column("name").localizedUppercased
    /// ```
    public var localizedUppercased: SQLExpression {
        DatabaseFunction.localizedUppercase(sqlExpression)
    }
}

// MARK: - Date functions

/// A date modifier for SQLite date functions.
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_datefunc.html>
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
    
    /// See <https://www.sqlite.org/lang_datefunc.html>
    case weekday(Int)
    
    /// See <https://www.sqlite.org/lang_datefunc.html>
    case unixEpoch
    
    /// See <https://www.sqlite.org/lang_datefunc.html>
    case localTime
    
    /// See <https://www.sqlite.org/lang_datefunc.html>
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

/// The `JULIANDAY` SQL function.
///
/// For example:
///
/// ```swift
/// // JULIANDAY(date)
/// julianDay(Column("date"))
///
/// // JULIANDAY(date, '1 days')
/// julianDay(Column("date"), .day(1))
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_datefunc.html>
public func julianDay(_ value: some SQLSpecificExpressible, _ modifiers: SQLDateModifier...) -> SQLExpression {
    .function("JULIANDAY", [value.sqlExpression] + modifiers.map(\.sqlExpression))
}

// MARK: DATETIME(...)

/// The `DATETIME` SQL function.
///
/// For example:
///
/// ```swift
/// // DATETIME(date)
/// dateTime(Column("date"))
///
/// // DATETIME(date, '1 days')
/// dateTime(Column("date"), .day(1))
/// ```
///
/// Related SQLite documentation:<https://www.sqlite.org/lang_datefunc.html>
public func dateTime(_ value: some SQLSpecificExpressible, _ modifiers: SQLDateModifier...) -> SQLExpression {
    .function("DATETIME", [value.sqlExpression] + modifiers.map(\.sqlExpression))
}
