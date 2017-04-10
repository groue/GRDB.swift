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
            #if os(Linux)
            dateString = String(format: "%04d-%02d-%02d", year, month, day)
            #else
            dateString = NSString(format: "%04d-%02d-%02d", year, month, day) as String
            #endif
        default:
            dateString = nil
        }
        
        let timeString: String?
        switch format {
        case .YMD_HM, .HM:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            #if os(Linux)
            timeString = String(format: "%02d:%02d", hour, minute)
            #else
            timeString = NSString(format: "%02d:%02d", hour, minute) as String
            #endif
        case .YMD_HMS, .HMS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            #if os(Linux)
            timeString = String(format: "%02d:%02d:%02d", hour, minute, second)
            #else
            timeString = NSString(format: "%02d:%02d:%02d", hour, minute, second) as String
            #endif
        case .YMD_HMSS, .HMSS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            let nanosecond = dateComponents.nanosecond ?? 0
            #if os(Linux)
            timeString = String(format: "%02d:%02d:%02d.%03d", hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0)))
            #else
            timeString = NSString(format: "%02d:%02d:%02d.%03d", hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0))) as String
            #endif
        default:
            timeString = nil
        }
        
        return [dateString, timeString].flatMap { $0 }.joined(separator: " ").databaseValue
    }
    
    /// Returns a DatabaseDateComponents if *databaseValue* contains a
    /// valid date.
    public static func fromDatabaseValue(_ databaseValue: DatabaseValue) -> DatabaseDateComponents? {
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
        
        var dateComponents = DateComponents()
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = CharacterSet()
        
        let hasDate: Bool
        
        // YYYY or HH
        var initialNumber: Int = 0
        #if os(Linux)
        if !scanner.scanInteger(&initialNumber) {
            return nil
        }
        #else
        if !scanner.scanInt(&initialNumber) {
            return nil
        }
        #endif
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
            #if os(Linux)
            if nil == scanner.scanString(string: "-") {
                return nil
            }
            #else
            if !scanner.scanString("-", into: nil) {
                return nil
            }
            #endif
            
            // MM
            var month: Int = 0
            #if os(Linux)
            if scanner.scanInteger(&month) && month >= 1 && month <= 12 {
                dateComponents.month = month
            } else {
                return nil
            }
            #else
            if scanner.scanInt(&month) && month >= 1 && month <= 12 {
                dateComponents.month = month
            } else {
                return nil
            }
            #endif
            
            // -
            #if os(Linux)
            if nil == scanner.scanString(string: "-") {
                return nil
            }
            #else
            if !scanner.scanString("-", into: nil) {
                return nil
            }
            #endif
            
            // DD
            var day: Int = 0
            #if os(Linux)
            if scanner.scanInteger(&day) && day >= 1 && day <= 31 {
                dateComponents.day = day
            } else {
                return nil
            }
            #else
            if scanner.scanInt(&day) && day >= 1 && day <= 31 {
                dateComponents.day = day
            } else {
                return nil
            }
            #endif
            
            // YYYY-MM-DD
            #if os(Linux)
            if scanner.atEnd {
                return DatabaseDateComponents(dateComponents, format: .YMD)
            }
            #else
            if scanner.isAtEnd {
                return DatabaseDateComponents(dateComponents, format: .YMD)
            }
            #endif
            
            // T/space
            #if os(Linux)
            if nil == scanner.scanString(string: "T") && nil == scanner.scanString(string: " ") {
                return nil
            }
            #else
            if !scanner.scanString("T", into: nil) && !scanner.scanString(" ", into: nil) {
                return nil
            }
            #endif
            
            // HH
            var hour: Int = 0
            #if os(Linux)
            if scanner.scanInteger(&hour) && hour >= 0 && hour <= 23 {
                dateComponents.hour = hour
            } else {
                return nil
            }
            #else
            if scanner.scanInt(&hour) && hour >= 0 && hour <= 23 {
                dateComponents.hour = hour
            } else {
                return nil
            }
            #endif
            
        default:
            return nil
        }
        
        // :
        #if os(Linux)
        if nil == scanner.scanString(string: ":") {
            return nil
        }
        #else
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        #endif
        
        // MM
        var minute: Int = 0
        #if os(Linux)
        if scanner.scanInteger(&minute) && minute >= 0 && minute <= 59 {
            dateComponents.minute = minute
        } else {
            return nil
        }
        #else
        if scanner.scanInt(&minute) && minute >= 0 && minute <= 59 {
            dateComponents.minute = minute
        } else {
            return nil
        }
        #endif
        
        // [YYYY-MM-DD] HH:MM
        #if os(Linux)
        if scanner.atEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HM)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HM)
            }
        }
        #else
        if scanner.isAtEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HM)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HM)
            }
        }
        #endif
        
        // :
        #if os(Linux)
        if nil == scanner.scanString(string: ":") {
            return nil
        }
        #else
        if !scanner.scanString(":", into: nil) {
            return nil
        }
        #endif
        
        // SS
        var second: Int = 0
        #if os(Linux)
        if scanner.scanInteger(&second) && second >= 0 && second <= 59 {
            dateComponents.second = second
        } else {
            return nil
        }
        #else
        if scanner.scanInt(&second) && second >= 0 && second <= 59 {
            dateComponents.second = second
        } else {
            return nil
        }
        #endif
        
        // [YYYY-MM-DD] HH:MM:SS
        #if os(Linux)
        if scanner.atEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HMS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMS)
            }
        }
        #else
        if scanner.isAtEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HMS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMS)
            }
        }
        #endif
        
        // .
        #if os(Linux)
        if nil == scanner.scanString(string: ".") {
            return nil
        }
        #else
        if !scanner.scanString(".", into: nil) {
            return nil
        }
        #endif
        
        // SSS
        #if os(Linux)
        guard var millisecondDigits = scanner.scanCharactersFromSet(.decimalDigits) else {
            return nil
        }
        if millisecondDigits.characters.count > 3 {
            millisecondDigits = NSString(string: millisecondDigits).substring(to: 3)
        }
        dateComponents.nanosecond = NSString(string: millisecondDigits).integerValue * 1_000_000
        #else
        var millisecondDigits: NSString? = nil
        if scanner.scanCharacters(from: .decimalDigits, into: &millisecondDigits), var millisecondDigits = millisecondDigits {
            if millisecondDigits.length > 3 {
                millisecondDigits = NSString(string: millisecondDigits.substring(to: 3))
            }
            dateComponents.nanosecond = millisecondDigits.integerValue * 1_000_000
        } else {
            return nil
        }
        #endif
        
        // [YYYY-MM-DD] HH:MM:SS.SSS
        #if os(Linux)
        if scanner.atEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HMSS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMSS)
            }
        }
        #else
        if scanner.isAtEnd {
            if hasDate {
                return DatabaseDateComponents(dateComponents, format: .YMD_HMSS)
            } else {
                return DatabaseDateComponents(dateComponents, format: .HMSS)
            }
        }
        #endif
        
        // Unknown format
        return nil
    }
}
