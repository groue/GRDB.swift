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

class DatabaseValueTests: GRDBTestCase {
    
    func testDatabaseValueAdoptsDatabaseValueConvertible() {
        assertNoError {
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE integers (integer INTEGER)")
                try db.execute("INSERT INTO integers (integer) VALUES (1)")
                let databaseValue: DatabaseValue = Row.fetchOne(db, "SELECT * FROM integers")!.value(named: "integer")!               // Triggers DatabaseValue.init?(databaseValue: DatabaseValue)
                let count = Int.fetchOne(db, "SELECT COUNT(*) FROM integers WHERE integer = ?", arguments: [databaseValue])!   // Triggers DatabaseValue.databaseValue
                XCTAssertEqual(count, 1)
            }
        }
    }
    
    func testDatabaseValueEquatable() {
        let fooBlob = Blob("foo".dataUsingEncoding(NSUTF8StringEncoding))!
        let barBlob = Blob("bar".dataUsingEncoding(NSUTF8StringEncoding))!
        
        XCTAssertEqual(DatabaseValue.Null, DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue.Real(1.0))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue.Text("foo"))
        XCTAssertNotEqual(DatabaseValue.Null, DatabaseValue.Blob(fooBlob))
        
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue.Integer(1), DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Integer(2))
        XCTAssertEqual(DatabaseValue.Integer(1), DatabaseValue.Real(1.0))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Real(1.1))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Real(2.0))
        XCTAssertEqual(DatabaseValue.Integer(1 << 53), DatabaseValue.Real(Double(1 << 53)))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue.Integer(1 << 53 + 1), DatabaseValue.Real(Double(1 << 53 + 1)))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue.Integer(1 << 54), DatabaseValue.Real(Double(1 << 54)))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue.Integer(Int64.max), DatabaseValue.Real(Double(Int64.max)))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Text("foo"))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Text("1"))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Text("1.0"))
        XCTAssertNotEqual(DatabaseValue.Integer(1), DatabaseValue.Blob(fooBlob))
        
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Null)
        XCTAssertEqual(DatabaseValue.Real(1.0), DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Real(1.1), DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Integer(2))
        XCTAssertEqual(DatabaseValue.Real(1.0), DatabaseValue.Real(1.0))
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Real(2.0))
        XCTAssertEqual(DatabaseValue.Real(Double(1 << 53)), DatabaseValue.Integer(1 << 53))                 // Any integer up to 2^53 has an exact representation as a IEEE-754 double...
        XCTAssertNotEqual(DatabaseValue.Real(Double(1 << 53 + 1)), DatabaseValue.Integer(1 << 53 + 1))      // ... 2^53 + 1 does not....
        XCTAssertEqual(DatabaseValue.Real(Double(1 << 54)), DatabaseValue.Integer(1 << 54))                 // ... but 2^54 does.
        XCTAssertNotEqual(DatabaseValue.Real(Double(Int64.max)), DatabaseValue.Integer(Int64.max))          // ... and Int64.max does not.
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Text("foo"))
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Text("1"))
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Text("1.0"))
        XCTAssertNotEqual(DatabaseValue.Real(1.0), DatabaseValue.Blob(fooBlob))
        
        XCTAssertNotEqual(DatabaseValue.Text("foo"), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue.Text("foo"), DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Text("foo"), DatabaseValue.Real(1.0))
        XCTAssertEqual(DatabaseValue.Text("foo"), DatabaseValue.Text("foo"))
        XCTAssertNotEqual(DatabaseValue.Text("foo"), DatabaseValue.Text("bar"))
        XCTAssertNotEqual(DatabaseValue.Text("foo"), DatabaseValue.Blob(fooBlob))
        
        XCTAssertNotEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Null)
        XCTAssertNotEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Integer(1))
        XCTAssertNotEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Real(1.0))
        XCTAssertNotEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Text("foo"))
        XCTAssertEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Blob(fooBlob))
        XCTAssertNotEqual(DatabaseValue.Blob(fooBlob), DatabaseValue.Blob(barBlob))
    }
}
