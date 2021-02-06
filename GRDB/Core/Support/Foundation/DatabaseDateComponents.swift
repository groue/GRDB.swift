import Foundation

/// DatabaseDateComponents reads and stores DateComponents in the database.
public struct DatabaseDateComponents: DatabaseValueConvertible, StatementColumnConvertible, Codable {
    
    /// The available formats for reading and storing date components.
    public enum Format: String {
        
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
    /// - parameters:
    ///     - dateComponents: An optional DateComponents.
    ///     - format: The format used for storing the date components in
    ///       the database.
    public init(_ dateComponents: DateComponents, format: Format) {
        self.format = format
        self.dateComponents = dateComponents
    }
    
    // MARK: - StatementColumnConvertible adoption
    
    /// Returns a value initialized from a raw SQLite statement pointer.
    ///
    /// - parameters:
    ///     - sqliteStatement: A pointer to an SQLite statement.
    ///     - index: The column index.
    public init?(sqliteStatement: SQLiteStatement, index: Int32) {
        guard let cString = sqlite3_column_text(sqliteStatement, index) else {
            return nil
        }
        let length = Int(sqlite3_column_bytes(sqliteStatement, index)) // avoid an strlen
        let optionalComponents = cString.withMemoryRebound(
            to: Int8.self,
            capacity: length + 1 /* trailing \0 */) { cString in
            SQLiteDateParser().components(cString: cString, length: length)
        }
        guard let components = optionalComponents else {
            return nil
        }
        self.dateComponents = components.dateComponents
        self.format = components.format
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
            dateString = String(format: "%04d-%02d-%02d", year, month, day)
        default:
            dateString = nil
        }
        
        let timeString: String?
        switch format {
        case .YMD_HM, .HM:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            timeString = String(format: "%02d:%02d", hour, minute)
        case .YMD_HMS, .HMS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            timeString = String(format: "%02d:%02d:%02d", hour, minute, second)
        case .YMD_HMSS, .HMSS:
            let hour = dateComponents.hour ?? 0
            let minute = dateComponents.minute ?? 0
            let second = dateComponents.second ?? 0
            let nanosecond = dateComponents.nanosecond ?? 0
            timeString = String(
                format: "%02d:%02d:%02d.%03d",
                hour, minute, second, Int(round(Double(nanosecond) / 1_000_000.0)))
        default:
            timeString = nil
        }
        
        return [dateString, timeString].compactMap { $0 }.joined(separator: " ").databaseValue
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
        
        return SQLiteDateParser().components(from: string)
    }
    
    // MARK: - Codable adoption
    
    
    /// Creates a new instance by decoding from the given decoder.
    ///
    /// - parameters:
    ///     - decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        guard let decodedValue = DatabaseDateComponents.fromDatabaseValue(stringValue.databaseValue) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unable to initialise databaseDateComponent")
        }
        self = decodedValue
    }
    
    /// Encodes this value into the given encoder.
    ///
    /// - parameters:
    ///     - encoder: The encoder to write data to.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String.fromDatabaseValue(databaseValue)!)
    }
}
