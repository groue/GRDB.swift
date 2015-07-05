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
    
    override var databaseDictionary: [String: SQLiteValueConvertible?] {
        return ["personID": personID, "countryName": countryName, "grantedTimestamp": DBDate(grantedDate)]
    }
    
    override func updateFromDatabaseRow(row: Row) {
        if let v = row.sqliteValue(named: "personID") { personID = v.value() }
        if let v = row.sqliteValue(named: "countryName") { countryName = v.value() }
        if let v = row.sqliteValue(named: "grantedTimestamp") { grantedDate = (v.value() as DBDate?)?.date }
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


class PrimaryKeyMultipleTests: RowModelTestCase {
    
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
    
    func testSelectWithDictionaryPrimaryKey() {
        assertNoError {
            var citizenshipKey: [String: SQLiteValueConvertible?]? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                try citizenship.insert(db)
                
                citizenshipKey = ["personID": citizenship.personID, "countryName": citizenship.countryName] // tested key
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let citizenship = db.fetchOne(Citizenship.self, primaryKey: Bindings(citizenshipKey!))!
                XCTAssertEqual(citizenship.countryName!, "France")
            }
        }
    }
    
    func testSelectWithArrayPrimaryKey() {
        assertNoError {
            var citizenshipKey: [SQLiteValueConvertible?]? = nil
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                try citizenship.insert(db)
                
                // Order matchs Citizenship.databasePrimaryKey columns
                citizenshipKey = [citizenship.personID, citizenship.countryName] // tested key
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let citizenship = db.fetchOne(Citizenship.self, primaryKey: Bindings(citizenshipKey!))!
                XCTAssertEqual(citizenship.countryName!, "France")
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur")
                try arthur.insert(db)
                
                let barbara = Person(name: "Barbara")
                try barbara.insert(db)
                
                try arthur.delete(db)   // The tested method
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let persons = db.fetchAll(Person.self, "SELECT * FROM persons ORDER BY name")
                XCTAssertEqual(persons.count, 1)
                XCTAssertEqual(persons.first!.name!, "Barbara")
            }
        }
    }
}
