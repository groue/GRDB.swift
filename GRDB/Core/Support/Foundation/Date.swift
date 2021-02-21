import Foundation

#if !os(Linux)
/// NSDate is stored in the database using the format
/// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
extension NSDate: DatabaseValueConvertible {
    /// Returns a database value that contains the date encoded as
    /// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
    public var databaseValue: DatabaseValue {
        (self as Date).databaseValue
    }
    
    /// Returns a date initialized from dbValue, if possible.
    ///
    /// If database value contains a number, that number is interpreted as a
    /// timeinterval since 00:00:00 UTC on 1 January 1970.
    ///
    /// If database value contains a string, that string is interpreted as a
    /// [SQLite date](https://sqlite.org/lang_datefunc.html) in the UTC time
    /// zone. Nil is returned if the date string does not contain at least the
    /// year, month and day components. Other components (minutes, etc.)
    /// are set to zero if missing.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let date = Date.fromDatabaseValue(dbValue) else {
            return nil
        }
        return cast(date)
    }
}
#endif

/// Date is stored in the database using the format
/// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
extension Date: DatabaseValueConvertible {
    /// Returns a database value that contains the date encoded as
    /// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
    public var databaseValue: DatabaseValue {
        storageDateFormatter.string(from: self).databaseValue
    }
    
    /// Returns a date initialized from dbValue, if possible.
    ///
    /// If database value contains a number, that number is interpreted as a
    /// timeinterval since 00:00:00 UTC on 1 January 1970.
    ///
    /// If database value contains a string, that string is interpreted as a
    /// [SQLite date](https://sqlite.org/lang_datefunc.html) in the UTC time
    /// zone. Nil is returned if the date string does not contain at least the
    /// year, month and day components. Other components (minutes, etc.)
    /// are set to zero if missing.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Date? {
        if let databaseDateComponents = DatabaseDateComponents.fromDatabaseValue(dbValue) {
            return Date(databaseDateComponents: databaseDateComponents)
        }
        if let timestamp = Double.fromDatabaseValue(dbValue) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    @usableFromInline
    init?(databaseDateComponents: DatabaseDateComponents) {
        guard databaseDateComponents.format.hasYMDComponents else {
            // Refuse to turn hours without any date information into Date:
            return nil
        }
        guard let date = UTCCalendar.date(from: databaseDateComponents.dateComponents) else {
            return nil
        }
        self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
    }
    
    /// Creates a date from a [Julian Day](https://en.wikipedia.org/wiki/Julian_day).
    public init?(julianDay: Double) {
        // Conversion uses the same algorithm as SQLite: https://www.sqlite.org/src/artifact/8ec787fed4929d8c
        // TODO: check for overflows one day, and return nil when computation can't complete.
        let JD = Int64(julianDay * 86400000)
        let Z = Int(((JD + 43200000)/86400000))
        var A = Int(((Double(Z) - 1867216.25)/36524.25))
        A = Z + 1 + A - (A/4)
        let B = A + 1524
        let C = Int(((Double(B) - 122.1)/365.25))
        let D = (36525*(C&32767))/100
        let E = Int((Double(B-D)/30.6001))
        let X1 = Int((30.6001*Double(E)))
        let day = B - D - X1
        let month = E<14 ? E-1 : E-13
        let year = month>2 ? C - 4716 : C - 4715
        var s = Int(((JD + 43200000) % 86400000))
        var second = Double(s)/1000.0
        s = Int(second)
        second -= Double(s)
        let hour = s/3600
        s -= hour*3600
        let minute = s/60
        second += Double(s - minute*60)
        
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = Int(second)
        dateComponents.nanosecond = Int((second - Double(Int(second))) * 1.0e9)
        
        guard let date = UTCCalendar.date(from: dateComponents) else {
            return nil
        }
        self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
    }
}

extension Date: StatementColumnConvertible {
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    @inlinable
    public init?(sqliteStatement: SQLiteStatement, index: Int32) {
        switch sqlite3_column_type(sqliteStatement, index) {
        case SQLITE_INTEGER, SQLITE_FLOAT:
            self.init(timeIntervalSince1970: sqlite3_column_double(sqliteStatement, index))
        case SQLITE_TEXT:
            guard let components = DatabaseDateComponents(sqliteStatement: sqliteStatement, index: index),
                  let date = Date(databaseDateComponents: components)
            else {
                return nil
            }
            self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
        default:
            return nil
        }
    }
}

/// The DatabaseDate date formatter for stored dates.
private let storageDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter
}()

// The NSCalendar for stored dates.
private let UTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()
