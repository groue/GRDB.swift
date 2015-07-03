//
//  PrimaryKeyMultipleTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 03/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class Citizenship: RowModel {
    var personID: Int64?
    var countryName: String?
    var grantedDate: NSDate?
    
    override class var databaseTableName: String? {
        return "citizenships"
    }
    
    override class var databasePrimaryKey: PrimaryKey {
        return .Multiple(["personID", "countryName"])
    }
    
    override var databaseDictionary: [String: DatabaseValue?] {
        return ["personID": personID, "countryName": countryName, "grantedTimestamp": grantedDate?.timeIntervalSince1970]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if row.hasColumn("personID") { personID = row.value(named: "personID") }
        if row.hasColumn("countryName") { countryName = row.value(named: "countryName") }
        if row.hasColumn("grantedTimestamp") {
            if let timestamp: NSTimeInterval = row.value(named: "grantedTimestamp") {
                grantedDate = NSDate(timeIntervalSince1970: timestamp)
            } else {
                grantedDate = nil
            }
        }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE citizenships (" +
                "personID INTEGER NOT NULL " +
                "         REFERENCES persons(ID) " +
                "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "countryName TEXT NOT NULL, " +
                "grantedTimestamp DOUBLE, " +
                "PRIMARY KEY (personID, countryName)" +
            ")")
    }
}


class PrimaryKeyMultipleTests: RowModelTests {
    
    func testInsert() {
        // Models with Multiple primary key should be able to be inserted when
        // their primary key is set.
        
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
            let dateComponents = NSDateComponents()
            dateComponents.year = 1973
            dateComponents.month = 09
            dateComponents.day = 18
            let date = calendar.dateFromComponents(dateComponents)!
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let citizenship = Citizenship()
            citizenship.personID = arthur.id
            citizenship.countryName = "France"
            citizenship.grantedDate = date
            
            try dbQueue.inTransaction { db in
                // The tested method
                try citizenship.insert(db)
                
                // After insertion, primary key is still set
                XCTAssertEqual(citizenship.personID!, arthur.id!)
                XCTAssertEqual(citizenship.countryName!, "France")
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let citizenships = db.fetchAll(Citizenship.self, "SELECT * FROM citizenships")
                XCTAssertEqual(citizenships.count, 1)
                XCTAssertEqual(citizenships.first!.personID!, arthur.id!)
                XCTAssertEqual(citizenships.first!.countryName!, "France")
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: citizenships.first!.grantedDate!), 1973)
            }
        }
    }
    
    func testInsertTwice() {
        assertNoError {
            let arthur = Person(name: "Arthur", age: 41)
            
            try dbQueue.inTransaction { db in
                try arthur.insert(db)
                return .Commit
            }
            
            let citizenship = Citizenship()
            citizenship.personID = arthur.id
            citizenship.countryName = "France"
            
            do {
                try dbQueue.inTransaction { db in
                    // The tested method
                    try citizenship.insert(db)
                    try citizenship.insert(db)
                    
                    return .Commit
                }
                XCTFail("Expected error")
            } catch is SQLiteError {
                // OK, this is expected
            }
        }
    }
    
    func testUpdate() {
        assertNoError {
            let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
            let dateComponents = NSDateComponents()
            dateComponents.year = 1973
            dateComponents.month = 09
            dateComponents.day = 18
            let date1 = calendar.dateFromComponents(dateComponents)!
            dateComponents.year = 2000
            let date2 = calendar.dateFromComponents(dateComponents)!
            XCTAssertFalse(date1.isEqualToDate(date2))
            
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                citizenship.grantedDate = date1
                try citizenship.insert(db)
                
                citizenship.grantedDate = date2
                try citizenship.update(db)  // The tested method
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let citizenships = db.fetchAll(Citizenship.self, "SELECT * FROM citizenships")
                XCTAssertEqual(citizenships.count, 1)
                XCTAssertEqual(citizenships.first!.countryName!, "France")
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: citizenships.first!.grantedDate!), 2000)
            }
        }
    }
    
}
