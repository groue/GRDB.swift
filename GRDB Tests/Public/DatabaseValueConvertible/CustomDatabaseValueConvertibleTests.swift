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

class CustomDatabaseValueConvertibleTests : GRDBTestCase {
    
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

    func testDBDate() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                do {
                    let dateComponents = NSDateComponents()
                    dateComponents.year = 1973
                    dateComponents.month = 09
                    dateComponents.day = 18
                    let date = calendar.dateFromComponents(dateComponents)!
                    try db.execute("INSERT INTO stuffs (creationDate) VALUES (?)", bindings: [DBDate(date)])
                }
                
                do {
                    let row = db.fetchOneRow("SELECT creationDate FROM stuffs")!
                    let date: DBDate = row.value(atIndex: 0)!
                    let year = calendar.component(NSCalendarUnit.Year, fromDate: date.date)
                    XCTAssertEqual(year, 1973)
                }
                
                do {
                    let date = db.fetchOne(DBDate.self, "SELECT creationDate FROM stuffs")!
                    let year = calendar.component(NSCalendarUnit.Year, fromDate: date.date)
                    XCTAssertEqual(year, 1973)
                }
                
                return .Rollback
            }
        }
    }
}
