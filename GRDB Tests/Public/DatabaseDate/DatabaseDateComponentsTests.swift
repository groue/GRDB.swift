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
    
    func testDatabaseDateComponentsFormatHM() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HM)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HM)
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
    
    func testDatabaseDateComponentsFormatHMS() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HMS)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11:12")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HMS)
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
    
    func testDatabaseDateComponentsFormatHMSS() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .HMSS)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "10:11:12.123")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.HMSS)
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
    
    func testDatabaseDateComponentsFormatYMD() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD)
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
    
    func testDatabaseDateComponentsFormatYMD_HM() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HM)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HM)
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

    func testDatabaseDateComponentsFormatYMD_HMS() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11:12")

                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMS)
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
    
    func testDatabaseDateComponentsFormatYMD_HMSS() {
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
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMSS)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "1973-09-18 10:11:12.123")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
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
    
    func testUndefinedDatabaseDateComponentsFormatYMD_HMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                
                let dateComponents = NSDateComponents()
                try db.execute("INSERT INTO dates (creationDate) VALUES (?)", arguments: [DatabaseDateComponents(dateComponents, format: .YMD_HMSS)])
                
                let string = db.fetchOne(String.self, "SELECT creationDate from dates")!
                XCTAssertEqual(string, "0000-01-01 00:00:00.000")
                
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate FROM dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
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
    
    func testDatabaseDateComponentsIsLexicallyComparableToCURRENT_TIMESTAMP() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                calendar.timeZone = NSTimeZone(forSecondsFromGMT: 0)
                do {
                    let date = NSDate().dateByAddingTimeInterval(-1)
                    let dateComponents = calendar.components([.Year, .Month, .Day, .Hour, .Minute, .Second], fromDate: date)
                    try db.execute(
                        "INSERT INTO dates (id, creationDate) VALUES (?,?)",
                        arguments: [1, DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
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
                        arguments: [3, DatabaseDateComponents(dateComponents, format: .YMD_HMS)])
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
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDD() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDHHMM() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HM)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDHHMMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMS)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, 3)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDHHMMSSSSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22 01:02:03.00456"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, 3)
                XCTAssertTrue(abs(databaseDateComponents.dateComponents.nanosecond - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDTHHMM() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HM)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, NSDateComponentUndefined)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDTHHMMSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMS)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, 3)
                XCTAssertEqual(databaseDateComponents.dateComponents.nanosecond, NSDateComponentUndefined)
            }
        }
    }
    
    func testDatabaseDateComponentsAcceptsFormatYYYYMMDDTHHMMSSSSS() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute(
                    "INSERT INTO dates (creationDate) VALUES (?)",
                    arguments: ["2015-07-22T01:02:03.00456"])
                let databaseDateComponents = db.fetchOne(DatabaseDateComponents.self, "SELECT creationDate from dates")!
                XCTAssertEqual(databaseDateComponents.format, DatabaseDateComponents.Format.YMD_HMSS)
                XCTAssertEqual(databaseDateComponents.dateComponents.year, 2015)
                XCTAssertEqual(databaseDateComponents.dateComponents.month, 7)
                XCTAssertEqual(databaseDateComponents.dateComponents.day, 22)
                XCTAssertEqual(databaseDateComponents.dateComponents.hour, 1)
                XCTAssertEqual(databaseDateComponents.dateComponents.minute, 2)
                XCTAssertEqual(databaseDateComponents.dateComponents.second, 3)
                XCTAssertTrue(abs(databaseDateComponents.dateComponents.nanosecond - 4_000_000) < 10)  // We actually get 4_000_008. Some precision is lost during the NSDateComponents -> NSDate conversion. Not a big deal.
            }
        }
    }
}
