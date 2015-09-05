import Foundation

/**
DatabaseDate reads and stores NSDate in the database using the format
"yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.

This format is not ISO-8601. However it is lexically comparable with the
format used by SQLite's `CURRENT_TIMESTAMP`: "yyyy-MM-dd HH:mm:ss".

Usage:

    // Store NSDate into the database:
    let date = NSDate()
    try db.execute("INSERT INTO persons (date, ...) " +
                                "VALUES (?, ...)",
                             arguments: [DatabaseDate(date), ...])

    // Extract NSDate from the database:
    let row in Row.fetchOne(db, "SELECT ...")!
    let date = (row.value(named: "date") as DatabaseDate?)?.date

    // Direct fetch:
    DatabaseDate.fetch(db, "SELECT ...", arguments: ...)    // AnySequence<DatabaseDate?>
    DatabaseDate.fetchAll(db, "SELECT ...", arguments: ...) // [DatabaseDate?]
    DatabaseDate.fetchOne(db, "SELECT ...", arguments: ...) // DatabaseDate?
    
    // Use NSDate in a RowModel:
    class Person : RowModel {
        var birthDate: NSDate?

        override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
            return ["birthDate": DatabaseDate(birthDate), ...]
        }
    
        override func updateFromRow(row: Row) {
            for (column, dbv) in row {
                switch column {
                case "birthDate": birthDate = (dbv.value() as DatabaseDate?)?.date
                case ...
                }
            }
            super.updateFromRow(row) // Subclasses are required to call super.
        }
    }

*/
public struct DatabaseDate : DatabaseValueConvertible {
    
    // MARK: - NSDate conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional NSDate, and the NSDate initializer is
    // failable:
    
    /// The represented date
    public let date: NSDate
    
    /**
    Creates a DatabaseDate from an NSDate.
    
    The result is nil if and only if *date* is nil.
    
    - parameter date: An optional NSDate.
    - returns: An optional DatabaseDate.
    */
    public init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    
    // MARK: - DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return .Text(DatabaseDate.storageDateFormatter.stringFromDate(date))
    }
    
    /**
    Create an instance initialized to `databaseValue`.
    
    Supported inputs are:
    
    - YYYY-MM-DD
    - YYYY-MM-DD HH:MM
    - YYYY-MM-DD HH:MM:SS
    - YYYY-MM-DD HH:MM:SS.SSS
    - YYYY-MM-DDTHH:MM
    - YYYY-MM-DDTHH:MM:SS
    - YYYY-MM-DDTHH:MM:SS.SSS
    - Julian Day Number
    */
    public init?(databaseValue: DatabaseValue) {
        if let julianDayNumber = Double(databaseValue: databaseValue) {
            // Julian day number
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

            let dateComponents = NSDateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = Int(second)
            dateComponents.nanosecond = Int((second - Double(Int(second))) * 1.0e9)
            
            self.init(DatabaseDate.UTCCalendar.dateFromComponents(dateComponents)!)
            
        } else if let databaseDateComponents = DatabaseDateComponents(databaseValue: databaseValue) {
            // Date components

            switch databaseDateComponents.format {
            case .YMD, .YMD_HM, .YMD_HMS, .YMD_HMSS:
                // Date is fully defined
                self.init(DatabaseDate.UTCCalendar.dateFromComponents(databaseDateComponents.dateComponents))
            default:
                // SQLite assumes 2000-01-01 when YMD are not provided, but this is
                // dangerous.
                return nil
            }
        } else {
            return nil
        }
    }
    
    
    // MARK: - Not Public
    
    static let UTCCalendar: NSCalendar = {
        let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        calendar.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return calendar
    }()
    
    /// The DatabaseDate date formatter for stored dates.
    static let storageDateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return formatter
        }()
}

/**
DatabaseDateComponents reads and stores NSDateComponents in the database.
*/
public struct DatabaseDateComponents : DatabaseValueConvertible {
    
    /// The available formats for reading and storing date components.
    public enum Format : String {
        
        /// The format "yyyy-MM-dd".
        case YMD = "yyyy-MM-dd"
        
        /// The format "yyyy-MM-dd HH:mm".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HM = "yyyy-MM-dd HH:mm"
        
        /// The format "yyyy-MM-dd HH:mm:ss".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HMS = "yyyy-MM-dd HH:mm:ss"
        
        /// The format "yyyy-MM-dd HH:mm:ss.SSS".
        ///
        /// This format is lexically comparable with SQLite's CURRENT_TIMESTAMP.
        case YMD_HMSS = "yyyy-MM-dd HH:mm:ss.SSS"
        
        /// The format "HH:mm".
        case HM = "HH:mm"
        
        /// The format "HH:mm:ss".
        case HMS = "HH:mm:ss"
        
        /// The format "HH:mm:ss.SSS".
        case HMSS = "HH:mm:ss.SSS"
    }
    
    // MARK: - NSDateComponents conversion
    
    /// The date components
    public let dateComponents: NSDateComponents
    
    /// The database format
    public let format: Format
    
    /**
    Creates a DatabaseDateComponents from an NSDateComponents and a format.
    
    The result is nil if and only if *dateComponents* is nil.
    
    - parameter dateComponents: An optional NSDateComponents.
    - parameter format: The format used for storing the date components in the
                        database.
    - returns: An optional DatabaseDateComponents.
    */
    public init?(_ dateComponents: NSDateComponents?, format: Format) {
        if let dateComponents = dateComponents {
            self.format = format
            self.dateComponents = dateComponents
        } else {
            return nil
        }
    }
    
    
    // MARK: - DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        let dateString: String?
        switch format {
        case .YMD_HM, .YMD_HMS, .YMD_HMSS, .YMD:
            let year = (dateComponents.year == NSDateComponentUndefined) ? 0 : dateComponents.year
            let month = (dateComponents.month == NSDateComponentUndefined) ? 1 : dateComponents.month
            let day = (dateComponents.day == NSDateComponentUndefined) ? 1 : dateComponents.day
            dateString = NSString(format: "%04d-%02d-%02d", year, month, day) as String
        default:
            dateString = nil
        }
        
        let timeString: String?
        switch format {
        case .YMD_HM, .HM:
            let hour = (dateComponents.hour == NSDateComponentUndefined) ? 0 : dateComponents.hour
            let minute = (dateComponents.minute == NSDateComponentUndefined) ? 0 : dateComponents.minute
            timeString = NSString(format: "%02d:%02d", hour, minute) as String
        case .YMD_HMS, .HMS:
            let hour = (dateComponents.hour == NSDateComponentUndefined) ? 0 : dateComponents.hour
            let minute = (dateComponents.minute == NSDateComponentUndefined) ? 0 : dateComponents.minute
            let second = (dateComponents.second == NSDateComponentUndefined) ? 0 : dateComponents.second
            timeString = NSString(format: "%02d:%02d:%02d", hour, minute, second) as String
        case .YMD_HMSS, .HMSS:
            let hour = (dateComponents.hour == NSDateComponentUndefined) ? 0 : dateComponents.hour
            let minute = (dateComponents.minute == NSDateComponentUndefined) ? 0 : dateComponents.minute
            let second = (dateComponents.second == NSDateComponentUndefined) ? 0 : dateComponents.second
            let nanosecond = (dateComponents.nanosecond == NSDateComponentUndefined) ? 0 : dateComponents.nanosecond
            timeString = NSString(format: "%02d:%02d:%02d.%03d", hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0))) as String
        default:
            timeString = nil
        }
        
        return .Text([dateString, timeString].flatMap { $0 }.joinWithSeparator(" "))
    }
    
    /// Create an instance initialized to `databaseValue`.
    public init?(databaseValue: DatabaseValue) {
        // https://www.sqlite.org/lang_datefunc.html
        //
        // Supported formats are:
        //
        // - YYYY-MM-DD
        // - YYYY-MM-DD HH:MM
        // - YYYY-MM-DD HH:MM:SS
        // - YYYY-MM-DD HH:MM:SS.SSS
        // - YYYY-MM-DDTHH:MM
        // - YYYY-MM-DDTHH:MM:SS
        // - YYYY-MM-DDTHH:MM:SS.SSS
        // - HH:MM
        // - HH:MM:SS
        // - HH:MM:SS.SSS
        
        // We need a String
        guard let string = String(databaseValue: databaseValue) else {
            return nil
        }
        
        let dateComponents = NSDateComponents()
        let scanner = NSScanner(string: string)
        scanner.charactersToBeSkipped = NSCharacterSet()
        
        let hasDate: Bool
        
        // YYYY or HH
        var initialNumber: Int = 0
        if !scanner.scanInteger(&initialNumber) {
            return nil
        }
        switch scanner.scanLocation {
        case 2:
            // HH
            hasDate = false
            
            let hour = initialNumber
            if hour >= 0 && hour <= 23 {
                dateComponents.hour = hour
            } else {
                return nil
            }
            
        case 4:
            // YYYY
            hasDate = true
            
            let year = initialNumber
            if year >= 0 && year <= 9999 {
                dateComponents.year = year
            } else {
                return nil
            }
            
            // -
            if !scanner.scanString("-", intoString: nil) {
                return nil
            }
            
            // MM
            var month: Int = 0
            if scanner.scanInteger(&month) && month >= 1 && month <= 12 {
                dateComponents.month = month
            } else {
                return nil
            }
            
            // -
            if !scanner.scanString("-", intoString: nil) {
                return nil
            }
            
            // DD
            var day: Int = 0
            if scanner.scanInteger(&day) && day >= 1 && day <= 31 {
                dateComponents.day = day
            } else {
                return nil
            }
            
            // YYYY-MM-DD
            if scanner.atEnd {
                self.init(dateComponents, format: .YMD)
                return
            }
            
            // T/space
            if !scanner.scanString("T", intoString: nil) && !scanner.scanString(" ", intoString: nil) {
                return nil
            }
            
            // HH
            var hour: Int = 0
            if scanner.scanInteger(&hour) && hour >= 0 && hour <= 23 {
                dateComponents.hour = hour
            } else {
                return nil
            }
            
        default:
            return nil
        }
        
        // :
        if !scanner.scanString(":", intoString: nil) {
            return nil
        }
        
        // MM
        var minute: Int = 0
        if scanner.scanInteger(&minute) && minute >= 0 && minute <= 59 {
            dateComponents.minute = minute
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM
        if scanner.atEnd {
            if hasDate {
                self.init(dateComponents, format: .YMD_HM)
            } else {
                self.init(dateComponents, format: .HM)
            }
            return
        }
        
        // :
        if !scanner.scanString(":", intoString: nil) {
            return nil
        }
        
        // SS
        var second: Int = 0
        if scanner.scanInteger(&second) && second >= 0 && second <= 59 {
            dateComponents.second = second
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM:SS
        if scanner.atEnd {
            if hasDate {
                self.init(dateComponents, format: .YMD_HMS)
            } else {
                self.init(dateComponents, format: .HMS)
            }
            return
        }
        
        // .
        if !scanner.scanString(".", intoString: nil) {
            return nil
        }
        
        // SSS
        var millisecondDigits: NSString? = nil
        if scanner.scanCharactersFromSet(NSCharacterSet.decimalDigitCharacterSet(), intoString: &millisecondDigits), var millisecondDigits = millisecondDigits {
            if millisecondDigits.length > 3 {
                millisecondDigits = millisecondDigits.substringToIndex(3)
            }
            dateComponents.nanosecond = millisecondDigits.integerValue * 1_000_000
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM:SS.SSS
        if scanner.atEnd {
            if hasDate {
                self.init(dateComponents, format: .YMD_HMSS)
            } else {
                self.init(dateComponents, format: .HMSS)
            }
            return
        }
        
        // Unknown format
        return nil
    }
}
