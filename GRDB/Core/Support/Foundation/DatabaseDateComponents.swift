import Foundation

/// DatabaseDateComponents reads and stores NSDateComponents in the database.
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
        
        var hasYMDComponents: Bool {
            switch self {
            case .YMD, .YMD_HM, .YMD_HMS, .YMD_HMSS:
                return true
            case .HM, .HMS, .HMSS:
                return false
            }
        }
    }
    
    // MARK: - NSDateComponents conversion
    
    /// The date components
    public let dateComponents: NSDateComponents
    
    /// The database format
    public let format: Format
    
    /// Creates a DatabaseDateComponents from an NSDateComponents and a format.
    ///
    /// The result is nil if and only if *dateComponents* is nil.
    ///
    /// - parameters:
    ///     - dateComponents: An optional NSDateComponents.
    ///     - format: The format used for storing the date components in
    ///       the database.
    /// - returns: An optional DatabaseDateComponents.
    public init?(_ dateComponents: NSDateComponents?, format: Format) {
        guard let dateComponents = dateComponents else {
            return nil
        }
        self.format = format
        self.dateComponents = dateComponents
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
        
        return [dateString, timeString].flatMap { $0 }.joinWithSeparator(" ").databaseValue
    }
    
    /// Returns a DatabaseDateComponents if *databaseValue* contains a
    /// valid date.
    public static func fromDatabaseValue(databaseValue: DatabaseValue) -> DatabaseDateComponents? {
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
        guard let string = String.fromDatabaseValue(databaseValue) else {
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
                return DatabaseDateComponents(dateComponents, format: .YMD)
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
                return DatabaseDateComponents(dateComponents, format: .YMD_HM)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HM)
            }
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
                return DatabaseDateComponents(dateComponents, format: .YMD_HMS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMS)
            }
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
                return DatabaseDateComponents(dateComponents, format: .YMD_HMSS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMSS)
            }
        }
        
        // Unknown format
        return nil
    }
}
