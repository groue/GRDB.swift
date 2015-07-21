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
DateTime reads and stores NSDate in the database using the format
"yyyy-MM-dd HH:mm:ss.SSS", in the UTC time zone.

This format *is not* ISO-8601. However it is lexically comparable with the
format used by SQLite's `CURRENT_TIMESTAMP`: "yyyy-MM-dd HH:mm:ss".

Usage:

    // Store NSDate into the database:
    let date = NSDate()
    try db.execute("INSERT INTO persons (date, ...) " +
                                "VALUES (?, ...)",
                             arguments: [DateTime(date), ...])

    // Extract NSDate from the database:
    let row in db.fetchOneRow("SELECT ...")!
    let date = (row.value(named: "date") as DateTime?)?.date

    // Direct fetch:
    db.fetch(DateTime.self, "SELECT ...", arguments: ...)    // AnySequence<DateTime?>
    db.fetchAll(DateTime.self, "SELECT ...", arguments: ...) // [DateTime?]
    db.fetchOne(DateTime.self, "SELECT ...", arguments: ...) // DateTime?
    
    // Use NSDate in a RowModel:
    class Person : RowModel {
        var birthDate: NSDate?

        override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
            return ["birthDate": DateTime(birthDate), ...]
        }
    
        override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
            switch column {
            case "birthDate": birthDate = (dbv.value() as DateTime?)?.date
            case ...
            default: super.setDatabaseValue(dbv, forColumn: column)
        }
    }

*/
public struct DateTime: DatabaseValueConvertible {
    
    // MARK: - NSDate conversion
    //
    // We consistently use the Swift nil to represent the database NULL: the
    // date property is a non-optional NSDate, and the NSDate initializer is
    // failable:
    
    /// The represented date
    public let date: NSDate
    
    /**
    Creates a DateTime from an NSDate.
    
    The result is nil if and only if *date* is nil.
    
    - parameter date: An optional NSDate.
    - returns: An optional DateTime.
    */
    public init?(_ date: NSDate?) {
        if let date = date {
            self.date = date
        } else {
            return nil
        }
    }
    
    
    // MARK: - DatabaseValueConvertible adoption
    
    /// The DateTime date formatter.
    public static let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        return formatter
    }()
    
    /// Returns a value that can be stored in the database.
    public var databaseValue: DatabaseValue {
        return .Text(DateTime.dateFormatter.stringFromDate(date))
    }
    
    /// Create an instance initialized to `databaseValue`.
    public init?(databaseValue: DatabaseValue) {
        // Why handle the raw DatabaseValue when GRDB built-in String
        // conversion does all the job for us?
        guard let string = String(databaseValue: databaseValue) else {
            return nil
        }
        self.init(DateTime.dateFormatter.dateFromString(string))
    }
}

