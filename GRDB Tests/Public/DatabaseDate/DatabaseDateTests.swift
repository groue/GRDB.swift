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

class DatabaseDateTests : GRDBTestCase {
    
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

    func testDatabaseDate() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                let dateComponents = NSDateComponents()
                dateComponents.year = 1973
                dateComponents.month = 9
                dateComponents.day = 18
                dateComponents.hour = 10
                dateComponents.minute = 11
                dateComponents.second = 12
                dateComponents.nanosecond = 123_456_789
                
                do {
                    let date = calendar.dateFromComponents(dateComponents)!
                    try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDate(date)])
                }
                
                do {
                    let date = DatabaseDate.fetchOne(db, "SELECT creationDate FROM dates")!.date
                    // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), dateComponents.year)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), dateComponents.month)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), dateComponents.day)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), dateComponents.hour)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), dateComponents.minute)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), dateComponents.second)
                    XCTAssertEqual(round(Double(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date)) / 1.0e6), round(Double(dateComponents.nanosecond) / 1.0e6))
                }
            }
        }
    }
    
    func testDatabaseDateIsLexicallyComparableToCURRENT_TIMESTAMP() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [1, DatabaseDate(NSDate().dateByAddingTimeInterval(-1))])
                
                try db.execute(
                    "INSERT INTO dates (id) VALUES (?)",
                    arguments: [2])
                
                try db.execute(
                    "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                    arguments: [3, DatabaseDate(NSDate().dateByAddingTimeInterval(1))])
                
                let ids = Int.fetchAll(db, "SELECT id FROM dates ORDER BY creationDate").map { $0! }
                XCTAssertEqual(ids, [1,2,3])
            }
        }
    }
    
    func testDatabaseDateFromUnparsableString() {
        let databaseDate = DatabaseDate(databaseValue: .Text("foo"))
        XCTAssertTrue(databaseDate == nil)
    }
    
    func testDatabaseDateDoesNotAcceptFormatHM() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02"])
                let databaseDate = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(databaseDate == nil)
            }
        }
    }
    
    func testDatabaseDateDoesNotAcceptFormatHMS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02:03"])
                let databaseDate = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(databaseDate == nil)
            }
        }
    }
    
    func testDatabaseDateDoesNotAcceptFormatHMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["01:02:03.00456"])
                let databaseDate = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")
                XCTAssertTrue(databaseDate == nil)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatYMD() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date), 0)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatYMD_HM() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date), 0)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatYMD_HMS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 3)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date), 0)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatYMD_HMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03.00456"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 3)
                XCTAssertTrue(abs(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
    
    func testDatabaseDateAcceptsJulianDayNumber() {
        assertNoError {
            try dbQueue.inDatabase { db in
                // 00:30:00.0 UT January 1, 2013 according to https://en.wikipedia.org/wiki/Julian_day
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: [2_456_293.520833])
                
                let string = String.fetchOne(db, "SELECT datetime(creationDate) from dates")!
                XCTAssertEqual(string, "2013-01-01 00:29:59")
                
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2013)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 29)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 59)
            }
        }
    }

    func testDatabaseDateAcceptsFormatIso8601YMD_HM() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date), 0)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatIso8601YMD_HMS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 3)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date), 0)
            }
        }
    }
    
    func testDatabaseDateAcceptsFormatIso8601YMD_HMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03.00456"])
                let date = DatabaseDate.fetchOne(db, "SELECT creationDate from dates")!.date
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), 2015)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), 7)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), 22)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), 1)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), 2)
                XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), 3)
                XCTAssertTrue(abs(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date) - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
}
