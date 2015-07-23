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


import XCTest
import GRDB

class DatabaseDateComponentsTests : GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createDates") { db in
            try db.execute(
                "CREATE TABLE dates (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "creationDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP" +
                ")")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601HourMinute() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601HourMinute)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601HourMinute)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601HourMinuteSecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601HourMinuteSecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11:12")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601HourMinuteSecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601HourMinuteSecondMillisecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601HourMinuteSecondMillisecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11:12.123")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601HourMinuteSecondMillisecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601Date() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601Date)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601Date)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601DateHourMinute() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601DateHourMinute)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18T10:11")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601DateHourMinute)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601DateHourMinuteSecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601DateHourMinuteSecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18T10:11:12")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601DateHourMinuteSecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatIso8601DateHourMinuteSecondMillisecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .Iso8601DateHourMinuteSecondMillisecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18T10:11:12.123")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.Iso8601DateHourMinuteSecondMillisecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
            }
        }
    }
    
    func testDatabaseDateComponentsFormatSQLDateHourMinute() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .SQLDateHourMinute)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.SQLDateHourMinute)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }

    func testDatabaseDateComponentsFormatSQLDateHourMinuteSecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .SQLDateHourMinuteSecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11:12")

                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.SQLDateHourMinuteSecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsFormatSQLDateHourMinuteSecondMillisecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .SQLDateHourMinuteSecondMillisecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11:12.123")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.SQLDateHourMinuteSecondMillisecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, dateComponents.year)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, dateComponents.month)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, dateComponents.day)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, dateComponents.hour)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, dateComponents.minute)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, dateComponents.second)
                XCTAssertEqual(round(Double(databaseDateComponents.dateComponents.nanosecond) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
            }
        }
    }
    
    func testUndefinedDatabaseDateComponentsFormatSQLDateHourMinuteSecondMillisecond() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .SQLDateHourMinuteSecondMillisecond)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "0000-01-01 00:00:00.000")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.SQLDateHourMinuteSecondMillisecond)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 0)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 0)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 0)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, 0)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, 0)
            }
        }
    }
    
    func testFormatSQLDateHourMinuteSecondIsLexicallyComparableToCURRENT_TIMESTAMP() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                do {
                    let date = NSDate().dateByAddingTimeInterval(-1)
                    let dateComponents = calendar.components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: date)
                    try db.execute(
                        "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                        arguments: [1, DatabaseDateComponents(dateComponents, format: .SQLDateHourMinuteSecond)])
                }
                do {
                    try db.execute(
                        "INSERT INTO dates (id) VALUES (?)",
                        arguments: [2])
                }
                do {
                    let date = NSDate().dateByAddingTimeInterval(1)
                    let dateComponents = calendar.components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: date)
                    try db.execute(
                        "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                        arguments: [3, DatabaseDateComponents(dateComponents, format: .SQLDateHourMinuteSecond)])
                }
                
                let ids = db.fetchAll(Int.self, "SELECT id FROM dates ORDER BY creationDate").map { $0! }
                XCTAssertEqual(ids, [1,2,3])
            }
        }
    }
    
    func testDatabaseDateComponentsFromUnparsableString() {
        let databaseDateComponents = DatabaseDateComponents(databaseValue: .Text("foo"))
        XCTAssertTrue(databaseDateComponents == nil)
    }
}
