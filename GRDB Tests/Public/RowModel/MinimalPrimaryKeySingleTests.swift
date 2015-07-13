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

// MinimalRowID is the most tiny class with a Single row primary key which
// supports read and write operations of RowModel.
class MinimalSingle: RowModel {
    var UUID: String!
    
    override class var databaseTable: Table? {
        return Table(named: "minimalSingles", primaryKey: .RowID("UUID"))
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["UUID": UUID]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "UUID": UUID = dbv.value()
        default:     super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE minimalSingles (UUID TEXT NOT NULL PRIMARY KEY)")
    }
}

class MinimalPrimaryKeySingleTests: RowModelTestCase {
    
    func testInsert() {
        // Models with RowID primary key should be able to be inserted with a
        // nil primary key. After the insertion, they have their primary key
        // set.
        
        assertNoError {
            let minimalSingle = MinimalSingle()
            minimalSingle.UUID = "foo"
            
            try dbQueue.inTransaction { db in
                // The tested method
                try minimalSingle.insert(db)
                return .Commit
            }
            
            // After insertion, model should be present in the database
            dbQueue.inDatabase { db in
                let minimalSingles = db.fetchAll(MinimalSingle.self, "SELECT * FROM minimalSingles")
                XCTAssertEqual(minimalSingles.count, 1)
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
            let minimalSingle = MinimalSingle()
            minimalSingle.UUID = "foo"
            
            do {
                try dbQueue.inTransaction { db in
                    try minimalSingle.insert(db)
                    try minimalSingle.insert(db)
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
                var minimalSingle = MinimalSingle()
                minimalSingle.UUID = "foo"
                
                try minimalSingle.insert(db)
                
                try minimalSingle.update(db)               // object still in database
                
                minimalSingle = db.fetchOne(MinimalSingle.self, primaryKey: minimalSingle.UUID)!
                try minimalSingle.delete(db)
                
                do {
                    try minimalSingle.update(db)           // object no longer in database
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
            let minimalSingle = MinimalSingle()
            minimalSingle.UUID = "foo"
            
            try dbQueue.inTransaction { db in
                try minimalSingle.save(db)      // insert
                let minimalSingleCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalSingles")!
                XCTAssertEqual(minimalSingleCount, 1)
                return .Commit
            }
            try dbQueue.inTransaction { db in
                try minimalSingle.save(db)      // update
                let minimalSingleCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalSingles")!
                XCTAssertEqual(minimalSingleCount, 1)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                try minimalSingle.delete(db)
                try minimalSingle.save(db)      // inserts
                let minimalSingleCount = db.fetchOne(Int.self, "SELECT COUNT(*) FROM minimalSingles")!
                XCTAssertEqual(minimalSingleCount, 1)
            }
        }
    }
    
    func testSelectWithPrimaryKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let UUID = "foo"
                
                var minimalSingle = MinimalSingle()
                minimalSingle.UUID = UUID
                try minimalSingle.insert(db)

                minimalSingle = db.fetchOne(MinimalSingle.self, primaryKey: UUID)! // The tested method
                XCTAssertEqual(minimalSingle.UUID!, UUID)
            }
        }
    }
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let UUID = "foo"
                
                var minimalSingle = MinimalSingle()
                minimalSingle.UUID = UUID
                try minimalSingle.insert(db)
                
                minimalSingle = db.fetchOne(MinimalSingle.self, key: ["UUID": UUID])! // The tested method
                XCTAssertEqual(minimalSingle.UUID!, UUID)
            }
        }
    }
    
    func testDelete() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let UUID1 = "foo"
                let minimalSingle1 = MinimalSingle()
                minimalSingle1.UUID = UUID1
                try minimalSingle1.insert(db)
                
                let UUID2 = "bar"
                let minimalSingle2 = MinimalSingle()
                minimalSingle2.UUID = UUID2
                try minimalSingle2.insert(db)
                
                try minimalSingle1.delete(db)   // The tested method
                
                let minimalSingles = db.fetchAll(MinimalSingle.self, "SELECT * FROM minimalSingles")
                XCTAssertEqual(minimalSingles.count, 1)
                XCTAssertEqual(minimalSingles.first!.UUID, UUID2)
            }
        }
    }
    
    func testReload() {
        assertNoError {
            try dbQueue.inTransaction { db in
                let minimalSingle = MinimalSingle()
                minimalSingle.UUID = "foo"
                try minimalSingle.insert(db)
                
                try minimalSingle.reload(db)                   // object still in database
                
                try minimalSingle.delete(db)
                
                do {
                    try minimalSingle.reload(db)               // object no longer in database
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
