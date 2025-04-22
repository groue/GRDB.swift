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

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// The `AVG` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // AVG(length)
/// average(Column("length"))
/// ```
public func average(
    _ value: some SQLSpecificExpressible,
    filter: (any SQLSpecificExpressible)? = nil)
-> SQLExpression {
    .aggregateFunction("AVG", [value.sqlExpression], filter: filter?.sqlExpression)
}
#else
/// The `AVG` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // AVG(length) FILTER (WHERE length > 0)
/// average(Column("length"), filter: Column("length") > 0)
/// ```
@available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.30+
public func average(
    _ value: some SQLSpecificExpressible,
    filter: some SQLSpecificExpressible)
-> SQLExpression {
    .aggregateFunction(
        "AVG", [value.sqlExpression],
        filter: filter.sqlExpression)
}

/// The `AVG` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // AVG(length)
/// average(Column("length"))
/// ```
public func average(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregateFunction("AVG", [value.sqlExpression])
}
#endif

/// The `CAST` SQL function.
///
/// For example:
///
/// ```swift
/// // CAST(value AS REAL)
/// cast(Column("value"), as: .real)
/// ```
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_expr.html#castexpr>
public func cast(_ expression: some SQLSpecificExpressible, as storageClass: Database.StorageClass) -> SQLExpression {
    .cast(expression.sqlExpression, as: storageClass)
}

/// The `COALESCE` SQL function.
///
/// For example:
///
/// ```swift
/// // COALESCE(value1, value2, ...)
/// coalesce([Column("value1"), Column("value2"), ...])
/// ```
///
/// Unlike the SQL function, `coalesce` accepts any number of arguments.
/// When `values` is empty, the result is `NULL`. When `values` contains a
/// single value, the result is this value. `COALESCE` is used from
/// two values upwards.
public func coalesce(_ values: some Collection<any SQLSpecificExpressible>) -> SQLExpression {
    // SQLite COALESCE wants at least two arguments.
    // There is no reason to apply the same limitation.
    guard let value = values.first else {
        return .null
    }
    if values.count > 1 {
        return .function("COALESCE", values.map { $0.sqlExpression })
    } else {
        return value.sqlExpression
    }
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

/// The `MAX` SQL multi-argument function.
///
/// For example:
///
/// ```swift
/// // MAX(score, 1000)
/// max(Column("score"), 1000)
/// ```
public func max(
    _ value1: any SQLSpecificExpressible,
    _ value2: any SQLExpressible,
    _ values: any SQLExpressible...
) -> SQLExpression {
    .simpleFunction("MAX", [value1.sqlExpression, value2.sqlExpression] + values.map(\.sqlExpression))
}

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// The `MAX` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MAX(score)
/// max(Column("score"))
/// ```
public func max(
    _ value: some SQLSpecificExpressible,
    filter: (any SQLSpecificExpressible)? = nil)
-> SQLExpression {
    .aggregateFunction("MAX", [value.sqlExpression], filter: filter?.sqlExpression)
}
#else
/// The `MAX` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MAX(score) FILTER (WHERE score < 0)
/// max(Column("score"), filter: Column("score") < 0)
/// ```
@available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.30+
public func max(
    _ value: some SQLSpecificExpressible,
    filter: some SQLSpecificExpressible)
-> SQLExpression {
    .aggregateFunction("MAX", [value.sqlExpression], filter: filter.sqlExpression)
}

/// The `MAX` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MAX(score)
/// max(Column("score"))
/// ```
public func max(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregateFunction("MAX", [value.sqlExpression])
}
#endif

/// The `MIN` SQL multi-argument function.
///
/// For example:
///
/// ```swift
/// // MIN(score, 1000)
/// min(Column("score"), 1000)
/// ```
public func min(
    _ value1: any SQLSpecificExpressible,
    _ value2: any SQLExpressible,
    _ values: any SQLExpressible...
) -> SQLExpression {
    .simpleFunction("MIN", [value1.sqlExpression, value2.sqlExpression] + values.map(\.sqlExpression))
}

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// The `MIN` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MIN(score)
/// min(Column("score"))
/// ```
public func min(
    _ value: some SQLSpecificExpressible,
    filter: (any SQLSpecificExpressible)? = nil) 
-> SQLExpression {
    .aggregateFunction("MIN", [value.sqlExpression], filter: filter?.sqlExpression)
}
#else
/// The `MIN` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MIN(score) FILTER (WHERE score > 0)
/// min(Column("score"), filter: Column("score") > 0)
/// ```
@available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.30+
public func min(
    _ value: some SQLSpecificExpressible,
    filter: some SQLSpecificExpressible)
-> SQLExpression {
    .aggregateFunction("MIN", [value.sqlExpression], filter: filter.sqlExpression)
}

/// The `MIN` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // MIN(score)
/// min(Column("score"))
/// ```
public func min(_ value: some SQLSpecificExpressible) -> SQLExpression {
    .aggregateFunction("MIN", [value.sqlExpression])
}
#endif

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// The `SUM` SQL aggregate function.
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
public func sum(
    _ value: some SQLSpecificExpressible,
    orderBy ordering: (any SQLOrderingTerm)? = nil,
    filter: (any SQLSpecificExpressible)? = nil)
-> SQLExpression
{
    .aggregateFunction(
        "SUM", [value.sqlExpression],
        ordering: ordering?.sqlOrdering,
        filter: filter?.sqlExpression)
}
#else
/// The `SUM` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // SUM(amount) FILTER (WHERE amount > 0)
/// sum(Column("amount"), filter: Column("amount") > 0)
/// ```
///
/// See also ``total(_:)``.
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
@available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.30+
public func sum(
    _ value: some SQLSpecificExpressible,
    filter: some SQLSpecificExpressible)
-> SQLExpression {
    .aggregateFunction(
        "SUM", [value.sqlExpression],
        filter: filter.sqlExpression)
}

/// The `SUM` SQL aggregate function.
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
    .aggregateFunction("SUM", [value.sqlExpression])
}
#endif

#if GRDBCUSTOMSQLITE || GRDBCIPHER
/// The `TOTAL` SQL aggregate function.
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
public func total(
    _ value: some SQLSpecificExpressible,
    orderBy ordering: (any SQLOrderingTerm)? = nil,
    filter: (any SQLSpecificExpressible)? = nil)
-> SQLExpression
{
    .aggregateFunction(
        "TOTAL", [value.sqlExpression],
        ordering: ordering?.sqlOrdering,
        filter: filter?.sqlExpression)
}
#else
/// The `TOTAL` SQL aggregate function.
///
/// For example:
///
/// ```swift
/// // TOTAL(amount) FILTER (WHERE amount > 0)
/// total(Column("amount"), filter: Column("amount") > 0)
/// ```
///
/// See also ``total(_:)``.
///
/// Related SQLite documentation: <https://www.sqlite.org/lang_aggfunc.html#sumunc>.
@available(iOS 14, macOS 10.16, tvOS 14, *) // SQLite 3.30+
public func total(
    _ value: some SQLSpecificExpressible,
    filter: some SQLSpecificExpressible)
-> SQLExpression {
    .aggregateFunction(
        "TOTAL", [value.sqlExpression],
        filter: filter.sqlExpression)
}

/// The `TOTAL` SQL aggregate function.
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
    .aggregateFunction("TOTAL", [value.sqlExpression])
}
#endif

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
public enum SQLDateModifier: SQLSpecificExpressible, Sendable {
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
