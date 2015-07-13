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

// MinimalRowID is the most tiny class with a RowID primary key which supports
// read and write operations of RowModel.
class MinimalRowID: RowModel {
    var id: Int64!
    
    override class var databaseTable: Table? {
        return Table(named: "minimalRowIDs", primaryKey: .RowID("id"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "id": id = dbv.value()
        default:   super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalRowIDs (id INTEGER PRIMARY KEY)")
    }
}

class MinimalPrimaryKeyRowIDTests: RowModelTestCase {

    func testInsert() {
        // Models with RowID primary key should be able to be inserted with a
        // nil primary key. After the insertion, they have their primary key
        // set.
        
        assertNoError {
            let minimalRowID = MinimalRowID()
            
            XCTAssertTrue(minimalRowID.id == nil)
            try dbQueue.inTransaction { db in
                // The tested method
                try minimalRowID.insert(db)
                
                // After insertion, ID should be set
                XCTAssertTrue(minimalRowID.id != nil)
                
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let minimalRowIDs = db.fetchAll(MinimalRowID.self, "SELECT * FROM minimalRowIDs")
                XCTAssertEqual(minimalRowIDs.count, 1)
            }
        }
    }
    
    func testInsertTwice() {
        // Models with RowID primary key should be able to be inserted with a
        // nil primary key. After the insertion, they have their primary key
        // set.
        //
        // The second insertion should fail because the primary key is already
        // taken.
        
        assertNoError {
            let minimalRowID = MinimalRowID()
            
            XCTAssertTrue(minimalRowID.id == nil)
            do {
                try dbQueue.inTransaction { db in
                    try minimalRowID.insert(db)
                    try minimalRowID.insert(db)
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
            try dbQueue.inTransaction { db in
                var minimalRowID = MinimalRowID()
                XCTAssertTrue(minimalRowID.id == nil)
                
                try minimalRowID.insert(db)
                
                try minimalRowID.update(db)               // object still in database
                
                minimalRowID = db.fetchOne(MinimalRowID.self, primaryKey: minimalRowID.id)!
                try minimalRowID.delete(db)
                
                do {
                    try minimalRowID.update(db)           // object no longer in database
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
            let minimalRowID = MinimalRowID()
            
            XCTAssertTrue(minimalRowID.id == nil)
            try dbQueue.inTransaction { db in
                try minimalRowID.save(db)       // insert
                let minimalRowIDCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalRowIDs")!
                XCTAssertEqual(minimalRowIDCount, 1)
                return .Commit
            }
            
            XCTAssertTrue(minimalRowID.id != nil)
            try dbQueue.inTransaction { db in
                try minimalRowID.save(db)       // update
                let minimalRowIDCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalRowIDs")!
                XCTAssertEqual(minimalRowIDCount, 1)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                try minimalRowID.delete(db)
                try minimalRowID.save(db)       // inserts
                let minimalRowIDCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalRowIDs")!
                XCTAssertEqual(minimalRowIDCount, 1)
            }
        }
    }
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            var id: Int64? = nil
            try dbQueue.inTransaction { db in
                let minimalRowID = MinimalRowID()
                try minimalRowID.insert(db)
                id = minimalRowID.id
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let minimalRowID = db.fetchOne(MinimalRowID.self, primaryKey: id!)! // The tested method
                XCTAssertEqual(minimalRowID.id!, id!)
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                var minimalRowID = MinimalRowID()
                try minimalRowID.insert(db)
                let id = minimalRowID.id
                
                minimalRowID = db.fetchOne(MinimalRowID.self, key: ["id": id])! // The tested method
                XCTAssertEqual(minimalRowID.id!, id!)
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            var id: Int64? = nil
            try dbQueue.inTransaction { db in
                let minimalRowID1 = MinimalRowID()
                try minimalRowID1.insert(db)
                
                let minimalRowID2 = MinimalRowID()
                try minimalRowID2.insert(db)
                id = minimalRowID2.id
                
                try minimalRowID1.delete(db)   // The tested method
                
                return .Commit
            }
            
            dbQueue.inDatabase { db in
                let minimalRowIDs = db.fetchAll(MinimalRowID.self, "SELECT * FROM minimalRowIDs")
                XCTAssertEqual(minimalRowIDs.count, 1)
                XCTAssertEqual(minimalRowIDs.first!.id, id!)
            }
        }
    }
    
    func testReload() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let minimalRowID = MinimalRowID()
                try minimalRowID.insert(db)
                
                try minimalRowID.reload(db)                   // object still in database
                
                try minimalRowID.delete(db)
                
                do {
                    try minimalRowID.reload(db)               // object no longer in database
                    XCTFail("Expected RowModelError.RowModelNotFound")
                } catch RowModelError.RowModelNotFound {
                } catch {
                    XCTFail("Expected RowModelError.RowModelNotFound, not \(error)")
                }
                
                return .Commit
            }
        }
    }
}
