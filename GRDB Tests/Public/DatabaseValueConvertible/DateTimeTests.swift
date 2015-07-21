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

class DateTimeTests : GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE stuffs (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "creationDate TEXT" +
                ")")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }

    func testDateTime() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
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
                    try db.execute("INSERT INTO stuffs (creationDate) VALUES (?)", arguments: [DateTime(date)])
                }
                
                do {
                    let row = db.fetchOneRow("SELECT creationDate FROM stuffs")!
                    let date = (row.value(atIndex: 0)! as DateTime).date
                    // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), dateComponents.year)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), dateComponents.month)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), dateComponents.day)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), dateComponents.hour)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), dateComponents.minute)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), dateComponents.second)
                    XCTAssertEqual(round(Double(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date)) / 1e6), round(Double(dateComponents.nanosecond) / 1e6))
                }
                
                do {
                    let date = db.fetchOne(DateTime.self, "SELECT creationDate FROM stuffs")!.date
                    // All components must be preserved, but nanosecond since ISO-8601 stores milliseconds.
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: date), dateComponents.year)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Month, fromDate: date), dateComponents.month)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Day, fromDate: date), dateComponents.day)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Hour, fromDate: date), dateComponents.hour)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Minute, fromDate: date), dateComponents.minute)
                    XCTAssertEqual(calendar.component(NSCalendarUnit.Second, fromDate: date), dateComponents.second)
                    XCTAssertEqual(round(Double(calendar.component(NSCalendarUnit.Nanosecond, fromDate: date)) / 1e6), round(Double(dateComponents.nanosecond) / 1e6))
                }
                
                return .Rollback
            }
        }
    }
}
