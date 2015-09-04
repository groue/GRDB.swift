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

class FetchableParent : DatabaseValueConvertible {
    /// Returns a value that can be stored in the database.
    var databaseValue: DatabaseValue {
        return DatabaseValue.Text("Parent")
    }
    
    /// Create an instance initialized to `databaseValue`.
    required init?(databaseValue: DatabaseValue) {
    }
    
    init() {
    }
}

class FetchableChild : FetchableParent {
    /// Returns a value that can be stored in the database.
    override var databaseValue: DatabaseValue {
        return DatabaseValue.Text("Child")
    }
}

class DatabaseValueConvertibleSubclassTests: GRDBTestCase {
    
    func testParent() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE parents (name TEXT)")
                try db.execute("INSERT INTO parents (name) VALUES (?)", arguments: [FetchableParent()])
                let string = String.fetchOne(db, "SELECT * FROM parents")!
                XCTAssertEqual(string, "Parent")
                FetchableParent.fetchOne(db, "SELECT * FROM parents")!
            }
        }
    }
    
    func testChild() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE children (name TEXT)")
                try db.execute("INSERT INTO children (name) VALUES (?)", arguments: [FetchableChild()])
                let string = String.fetchOne(db, "SELECT * FROM children")!
                XCTAssertEqual(string, "Child")
                FetchableChild.fetchOne(db, "SELECT * FROM children")!
            }
        }
    }
}
