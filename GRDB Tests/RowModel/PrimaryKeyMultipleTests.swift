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

// Citizenship has a multiple-column primary key.
class Citizenship: RowModel {
    var personID: Int64?
    var countryName: String?
    var grantedDate: NSDate?
    var native: Bool?
    
    override class var databaseTable: Table? {
        return Table(named: "citizenships", primaryKey: .Columns(["personID", "countryName"]))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return [
            "personID": personID,
            "countryName": countryName,
            "grantedDate": DBDate(grantedDate),
            "native": native]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "personID":    personID = dbv.value()
        case "countryName": countryName = dbv.value()
        case "grantedDate": grantedDate = (dbv.value() as DBDate?)?.date
        case "native":      native = dbv.value()
        default:            super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE citizenships (" +
                "personID INTEGER NOT NULL " +
                "         REFERENCES persons(ID) " +
                "         ON DELETE CASCADE ON UPDATE CASCADE, " +
                "countryName TEXT NOT NULL, " +
                "grantedDate TEXT, " +
                "native BOOLEAN, " +
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
            } catch is DatabaseError {
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
                
                var citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                citizenship.grantedDate = date1
                try citizenship.insert(db)
                
                citizenship.grantedDate = date2
                try citizenship.update(db)          // object still in database
                
                citizenship = db.fetchOne(Citizenship.self, "SELECT * FROM citizenships WHERE personID = ? AND countryName = ?", bindings: [citizenship.personID, citizenship.countryName])!
                XCTAssertEqual(citizenship.countryName!, "France")
                XCTAssertEqual(calendar.component(NSCalendarUnit.Year, fromDate: citizenship.grantedDate!), 2000)
                
                try citizenship.delete(db)
                do {
                    try citizenship.update(db)      // object no longer in database
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                } catch {
                    XCTFail("Expected RowModelError.RowModelNotFound, not \(error)")
                }
                
                return .Commit
            }
        }
    }
    
    func testSave() {
        assertNoError {
            let person = Person(name: "Arthur", age: 41)
            try dbQueue.inTransaction { db in
                try person.insert(db)
                return .Commit
            }
            
            let citizenship = Citizenship()
            citizenship.personID = person.id
            citizenship.countryName = "France"
            
            try dbQueue.inTransaction { db in
                try citizenship.save(db)       // insert
                let citizenshipCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM citizenships")!
                XCTAssertEqual(citizenshipCount, 1)
                return .Commit
            }
            
            try dbQueue.inTransaction { db in
                try citizenship.save(db)       // update
                let citizenshipCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM citizenships")!
                XCTAssertEqual(citizenshipCount, 1)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                try citizenship.delete(db)
                try citizenship.save(db)       // inserts
                let citizenshipCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM citizenships")!
                XCTAssertEqual(citizenshipCount, 1)
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                var citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                try citizenship.insert(db)
                
                citizenship = db.fetchOne(Citizenship.self, key: ["countryName": "France", "personID": arthur.id])!
                XCTAssertEqual(citizenship.countryName!, "France")
                XCTAssertEqual(citizenship.personID!, arthur.id)
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let citizenship1 = Citizenship()
                citizenship1.personID = arthur.id
                citizenship1.countryName = "France"
                try citizenship1.insert(db)
                
                let citizenship2 = Citizenship()
                citizenship2.personID = arthur.id
                citizenship2.countryName = "Spain"
                try citizenship2.insert(db)
                
                try citizenship1.delete(db)   // The tested method
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let citizenships = db.fetchAll(Citizenship.self, "SELECT * FROM citizenships")
                XCTAssertEqual(citizenships.count, 1)
                XCTAssertEqual(citizenships.first!.countryName!, "Spain")
            }
        }
    }
    
    func testReload() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let arthur = Person(name: "Arthur", age: 41)
                try arthur.insert(db)
                
                let citizenship = Citizenship()
                citizenship.personID = arthur.id
                citizenship.countryName = "France"
                citizenship.native = true
                try citizenship.insert(db)
                
                citizenship.native = false
                XCTAssertEqual(citizenship.native!, false)
                try citizenship.reload(db)                  // object still in database
                XCTAssertEqual(citizenship.native!, true)
                
                try citizenship.delete(db)
                
                citizenship.native = false
                XCTAssertEqual(citizenship.native!, false)
                do {
                    try citizenship.reload(db)              // object no longer in database
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                } catch {
                    XCTFail("Expected RowModelError.RowModelNotFound, not \(error)")
                }
                XCTAssertEqual(citizenship.native!, false)
                
                return .Commit
            }
        }
    }
}
