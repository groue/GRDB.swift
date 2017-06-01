import Foundation

/// NSDate is stored in the database using the format
/// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
extension NSDate : DatabaseValueConvertible {
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return storageDateFormatter.string(from: self as Date).databaseValue
    }
    
    /// Returns a Date initialized from *dbValue*, if possible.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        if let databaseDateComponents = DatabaseDateComponents.fromDatabaseValue(dbValue) {
            return cast(fromDatabaseDateComponents(databaseDateComponents))
        }
        if let julianDayNumber = Double.fromDatabaseValue(dbValue) {
            return cast(fromJulianDayNumber(julianDayNumber))
        }
        return nil
    }
    
    private static func fromJulianDayNumber(_ julianDayNumber: Double) -> Date? {
        // Conversion uses the same algorithm as SQLite: https://www.sqlite.org/src/artifact/8ec787fed4929d8c
        let JD = Int64(julianDayNumber * 86400000)
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
        
        return UTCCalendar.date(from: dateComponents)!
    }
    
    private static func fromDatabaseDateComponents(_ databaseDateComponents: DatabaseDateComponents) -> Date? {
        guard databaseDateComponents.format.hasYMDComponents else {
            // Refuse to turn hours without any date information into Date:
            return nil
        }
        return UTCCalendar.date(from: databaseDateComponents.dateComponents)!
    }
}

/// Date is stored in the database using the format
/// "yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.
extension Date : DatabaseValueConvertible { }

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
