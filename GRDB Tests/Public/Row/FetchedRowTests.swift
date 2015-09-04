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

class FetchedRowTests: GRDBTestCase {
    
    func testRowAsSequence() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                let row = Row.fetchOne(db, "SELECT * FROM ints")!
                
                var columnNames = [String]()
                var ints = [Int]()
                var bools = [Bool]()
                for (columnName, databaseValue) in row {
                    columnNames.append(columnName)
                    ints.append(databaseValue.value()! as Int)
                    bools.append(databaseValue.value()! as Bool)
                }
                
                XCTAssertEqual(columnNames, ["a", "b", "c"])
                XCTAssertEqual(ints, [0, 1, 2])
                XCTAssertEqual(bools, [false, true, true])
            }
        }
    }
    
    func testRowValueAtIndex() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                let row = Row.fetchOne(db, "SELECT * FROM ints")!

                XCTAssertEqual(row.value(atIndex: 0)! as Int, 0)
                XCTAssertEqual(row.value(atIndex: 1)! as Int, 1)
                XCTAssertEqual(row.value(atIndex: 2)! as Int, 2)
                
                XCTAssertEqual(row.value(atIndex: 0)! as Bool, false)
                XCTAssertEqual(row.value(atIndex: 1)! as Bool, true)
                XCTAssertEqual(row.value(atIndex: 2)! as Bool, true)
                
                // Expect fatal error:
                //
                // row.value(atIndex: -1)
                // row.value(atIndex: 3)
            }
        }
    }
    
    func testRowValueNamed() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE ints (a INTEGER, b INTEGER, c INTEGER)")
                try db.execute("INSERT INTO ints (a,b,c) VALUES (0, 1, 2)")
                let row = Row.fetchOne(db, "SELECT * FROM ints")!
                
                XCTAssertEqual(row.value(named: "a")! as Int, 0)
                XCTAssertEqual(row.value(named: "b")! as Int, 1)
                XCTAssertEqual(row.value(named: "c")! as Int, 2)
                
                XCTAssertEqual(row.value(named: "a")! as Bool, false)
                XCTAssertEqual(row.value(named: "b")! as Bool, true)
                XCTAssertEqual(row.value(named: "c")! as Bool, true)
                
                // Expect fatal error:
                // row.value(named: "foo")
                // row.value(named: "foo") as Int?
            }
        }
    }
}
