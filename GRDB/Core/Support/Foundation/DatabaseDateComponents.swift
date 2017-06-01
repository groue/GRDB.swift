import Foundation

/// DatabaseDateComponents reads and stores DateComponents in the database.
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
    public let dateComponents: DateComponents
    
    /// The database format
    public let format: Format
    
    /// Creates a DatabaseDateComponents from a DateComponents and a format.
    ///
    /// The result is nil if and only if *dateComponents* is nil.
    ///
    /// - parameters:
    ///     - dateComponents: An optional DateComponents.
    ///     - format: The format used for storing the date components in
    ///       the database.
    /// - returns: An optional DatabaseDateComponents.
    public init?(_ dateComponents: DateComponents?, format: Format) {
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
            let year = dateComponents.year ?? 0
            let month = dateComponents.month ?? 1
            let day = dateComponents.day ?? 1
            dateString = NSString(format: "%04d-%02d-%02d", year, month, day) as String
        default:
            dateString = nil
        }
        
        let timeString: String?
        switch format {
        case .YMD_HM, .HM:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            timeString = NSString(format: "%02d:%02d", hour, minute) as String
        case .YMD_HMS, .HMS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            timeString = NSString(format: "%02d:%02d:%02d", hour, minute, second) as String
        case .YMD_HMSS, .HMSS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            let nanosecond = dateComponents.nanosecond ?? 0
            timeString = NSString(format: "%02d:%02d:%02d.%03d", hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0))) as String
        default:
            timeString = nil
        }
        
        return [dateString, timeString].flatMap { $0 }.joined(separator: " ").databaseValue
    }
    
    /// Returns a DatabaseDateComponents if *dbValue* contains a
    /// valid date.
    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> DatabaseDateComponents? {
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
        guard let string = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        
        var dateComponents = DateComponents()
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = CharacterSet()
        
        let hasDate: Bool
        
        // YYYY or HH
        var initialNumber: Int = 0
        if !scanner.scanInt(&initialNumber) {
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
            if !scanner.scanString("-", into: nil) {
                return nil
            }
            
            // MM
            var month: Int = 0
            if scanner.scanInt(&month) && month >= 1 && month <= 12 {
                dateComponents.month = month
            } else {
                return nil
            }
            
            // -
            if !scanner.scanString("-", into: nil) {
                return nil
            }
            
            // DD
            var day: Int = 0
            if scanner.scanInt(&day) && day >= 1 && day <= 31 {
                dateComponents.day = day
            } else {
                return nil
            }
            
            // YYYY-MM-DD
            if scanner.isAtEnd {
                return DatabaseDateComponents(dateComponents, format: .YMD)
            }
            
            // T/space
            if !scanner.scanString("T", into: nil) && !scanner.scanString(" ", into: nil) {
                return nil
            }
            
            // HH
            var hour: Int = 0
            if scanner.scanInt(&hour) && hour >= 0 && hour <= 23 {
                dateComponents.hour = hour
            } else {
                return nil
            }
            
        default:
            return nil
        }
        
        // :
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        
        // MM
        var minute: Int = 0
        if scanner.scanInt(&minute) && minute >= 0 && minute <= 59 {
            dateComponents.minute = minute
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM
        if scanner.isAtEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HM)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HM)
            }
        }
        
        // :
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        
        // SS
        var second: Int = 0
        if scanner.scanInt(&second) && second >= 0 && second <= 59 {
            dateComponents.second = second
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM:SS
        if scanner.isAtEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HMS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMS)
            }
        }
        
        // .
        if !scanner.scanString(".", into: nil) {
            return nil
        }
        
        // SSS
        var millisecondDigits: NSString? = nil
        if scanner.scanCharacters(from: .decimalDigits, into: &millisecondDigits), var millisecondDigits = millisecondDigits {
            if millisecondDigits.length > 3 {
                millisecondDigits = NSString(string: millisecondDigits.substring(to: 3))
            }
            dateComponents.nanosecond = millisecondDigits.integerValue * 1_000_000
        } else {
            return nil
        }
        
        // [YYYY-MM-DD] HH:MM:SS.SSS
        if scanner.isAtEnd {
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
