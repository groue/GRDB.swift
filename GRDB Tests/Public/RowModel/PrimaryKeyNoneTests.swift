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

// Item has no primary key.
class Item: RowModel {
    var name: String?
    
    override class var databaseTable: Table? {
        return Table(named: "items")
    }
    
    override var storedDatabaseDictionary: [String: DatabaseValueConvertible?] {
        return ["name": name]
    }
    
    override func setDatabaseValue(dbv: DatabaseValue, forColumn column: String) {
        switch column {
        case "name":    name = dbv.value()
        default:        super.setDatabaseValue(dbv, forColumn: column)
        }
    }
    
    init (name: String? = nil) {
        self.name = name
        super.init()
    }
    
    required init(row: Row) {
        super.init(row: row)
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE items (" +
                "name NOT NULL" +
            ")")
    }
}

class PrimaryKeyNoneTests: RowModelTestCase {
    
    
    // MARK: - Insert
    
    func testInsertInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.insert(db)
                try rowModel.insert(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Save
    
    func testSaveInsertsARow() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.save(db)
                try rowModel.save(db)
                
                let names = String.fetchAll(db, "SELECT name FROM items").map { $0! }
                XCTAssertEqual(names, ["Table", "Table"])
            }
        }
    }
    
    
    // MARK: - Select
    
    func testSelectWithKey() {
        assertNoError {
            try dbQueue.inDatabase { db in
                let rowModel = Item(name: "Table")
                try rowModel.insert(db)
                
                let fetchedRowModel = Item.fetchOne(db, key: ["name": rowModel.name])!
                XCTAssertTrue(fetchedRowModel.name == rowModel.name)
            }
        }
    }
}
