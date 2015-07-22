//
// GRDB.swift
// https://github.com/groue/GRDB.swift
// Copyright (c) 2015 Gwendal Roué
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation

/**
DatabaseDate reads and stores NSDate in the database using the format
"yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.

This format *is not* ISO-8601. However it is lexically comparable with the
format used by SQLite's `CURRENT_TIMESTAMP`: "yyyy-MM-dd HH:mm:ss".

Usage:

    // Store NSDate into the database:
    let date = NSDate()
    try db.execute("INSERT INTO persons (date, ...) " +
                                "VALUES (?, ...)",
                             arguments: [DatabaseDate(date), ...])

    // Extract NSDate from the database:
    let row in db.fetchOneRow("SELECT ...")!
    let date = (row.value(named: "date") as DatabaseDate?)?.date

    // Direct fetch:
    db.fetch(DatabaseDate.self, "SELECT ...", arguments: ...)    // AnySequence<DatabaseDate?>
    db.fetchAll(DatabaseDate.self, "SELECT ...", arguments: ...) // [DatabaseDate?]
    db.fetchOne(DatabaseDate.self, "SELECT ...", arguments: ...) // DatabaseDate?
    
    // Use NSDate in a RowModel:
    class Person : RowModel {
        var birthDate: NSDate?

        override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
            return ["birthDate": DatabaseDate(birthDate), ...]
        }
    
        override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
            switch column {
            case "birthDate": birthDate = (dbv.value() as DatabaseDate?)?.date
            case ...
            default: super.setDatabaseValue(dbv, forColumn: column)
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
    
    /// Create an instance initialized to `databaseValue`.
    public init?(databaseValue: DatabaseValue) {
        // We need a string:
        guard let string = String(databaseValue: databaseValue) else {
            return nil
        }
        
        // We need date components:
        guard let dateComponents = dateComponentsFromSQLiteString(string) else {
            return nil
        }
        
        // We need at least year, month & day (we may get only hour & minutes):
        guard dateComponents.year != NSDateComponentUndefined && dateComponents.month != NSDateComponentUndefined && dateComponents.day != NSDateComponentUndefined else {
            return nil
        }
        
        // OK gimme the date
        self.init(DatabaseDate.UTCCalendar.dateFromComponents(dateComponents))
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

public struct DatabaseDateComponents : DatabaseValueConvertible {
    
    // MARK: - NSDateComponents conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional NSDateComponents, and the
    // NSDateComponents initializer is failable:
    
    /// The represented date
    public let dateComponents: NSDateComponents
    
    /**
    Creates a DatabaseDate from an NSDateComponents.
    
    The result is nil if and only if *dateComponents* is nil.
    
    - parameter dateComponents: An optional NSDateComponents.
    - returns: An optional DatabaseDate.
    */
    public init?(_ dateComponents: NSDateComponents?) {
        if let dateComponents = dateComponents {
            self.dateComponents = dateComponents
        } else {
            return nil
        }
    }
    
    
    // MARK: - DatabaseValueConvertible adoption
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return .Text(SQLiteStringFromDateComponents(dateComponents))
    }
    
    /// Create an instance initialized to `databaseValue`.
    public init?(databaseValue: DatabaseValue) {
        // We need a string:
        guard let string = String(databaseValue: databaseValue) else {
            return nil
        }
        
        self.init(dateComponentsFromSQLiteString(string))
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

private func SQLiteStringFromDateComponents(dateComponents: NSDateComponents) -> String {
    let yearDefined = dateComponents.year == NSDateComponentUndefined
    let monthDefined = dateComponents.month == NSDateComponentUndefined
    let dayDefined = dateComponents.day == NSDateComponentUndefined
    
    var dateString: String?
    switch (yearDefined, monthDefined, dayDefined) {
    case (false, false, false):
        dateString = nil
    case (true, true, true):
        dateString = NSString(format: "%04d-%02d-%02d", dateComponents.year, dateComponents.month, dateComponents.day) as String
    default:
        fatalError("Can't convert NSDateComponents into SQLite string, because it does not define all year, month and day components.")
    }
    
    let hourDefined = dateComponents.hour == NSDateComponentUndefined
    let minuteDefined = dateComponents.minute == NSDateComponentUndefined
    let secondDefined = dateComponents.second == NSDateComponentUndefined
    let nanosecondDefined = dateComponents.nanosecond == NSDateComponentUndefined
    
    var timeString: String?
    switch (hourDefined, minuteDefined, secondDefined, nanosecondDefined) {
    case (false, false, false, false):
        timeString = nil
    case (true, true, false, false):
        timeString = NSString(format: "%02d:%02d", dateComponents.hour, dateComponents.minute) as String
    case (true, true, true, false):
        timeString = NSString(format: "%02d:%02d:%02d", dateComponents.hour, dateComponents.minute, dateComponents.second) as String
    case (true, true, true, true):
        timeString = NSString(format: "%02d:%02d:%02d.%03d", dateComponents.hour, dateComponents.minute, dateComponents.second, Int(round(Double(dateComponents.nanosecond) / 1_000_0000.0))) as String
    default:
        fatalError("Can't convert NSDateComponents into SQLite string, because it does not define all year, month and day components.")
    }
    
    return " ".join([dateString, timeString].filter { $0 != nil }.map { $0! })
}

private func dateComponentsFromSQLiteString(string: String) -> NSDateComponents? {
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
    
    
    let dateComponents = NSDateComponents()
    let scanner = NSScanner(string: string)
    scanner.charactersToBeSkipped = NSCharacterSet()
    
    // YYYY or HH
    var initialNumber: Int = 0
    if !scanner.scanInteger(&initialNumber) {
        return nil
    }
    switch scanner.scanLocation {
    case 2:
        // HH
        let hour = initialNumber
        if hour >= 0 && hour <= 23 {
            dateComponents.hour = hour
        } else {
            return nil
        }
        
    case 4:
        // YYYY
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
            return dateComponents
        }
        
        // T/space
        if !(scanner.scanString("T", intoString: nil) || scanner.scanString(" ", intoString: nil)) {
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
    
    // YYYY-MM-DD HH:MM
    if scanner.atEnd {
        return dateComponents
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
    
    // YYYY-MM-DD HH:MM:SS
    if scanner.atEnd {
        return dateComponents
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
    
    return dateComponents
}
