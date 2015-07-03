//
//  CustomDatabaseValueTypeTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 02/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class CustomDatabaseValueTypeTests: GRDBTests {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute(
                "CREATE TABLE stuffs (" +
                    "ID INTEGER PRIMARY KEY, " +
                    "creationTimestamp DOUBLE" +
                ")")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }

    func testExample() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
                do {
                    let dateComponents = NSDateComponents()
                    dateComponents.year = 1973
                    dateComponents.month = 09
                    dateComponents.day = 18
                    let date = calendar.dateFromComponents(dateComponents)!
                    try db.execute("INSERT INTO stuffs (creationTimestamp) VALUES (?)", bindings: [DatabaseDate(date)])
                }
                
                do {
                    let row = db.fetchOneRow("SELECT creationTimestamp FROM stuffs")!
                    let date: DatabaseDate = row.value(atIndex: 0)!
                    let year = calendar.component(NSCalendarUnit.Year, fromDate: date.date)
                    XCTAssertEqual(year, 1973)
                }
                
                do {
                    let date = db.fetchOne(DatabaseDate.self, "SELECT creationTimestamp FROM stuffs")!
                    let year = calendar.component(NSCalendarUnit.Year, fromDate: date.date)
                    XCTAssertEqual(year, 1973)
                }
                
                return .Rollback
            }
        }
    }
}
