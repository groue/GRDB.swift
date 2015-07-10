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
@testable import GRDB

class DatabaseErrorTests: GRDBTestCase {
    
    func testDatabaseErrorThrownByUpdateStatementContainSQL() {
        dbQueue.inDatabase { db in
            do {
                try db.updateStatement("BLAH")
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 1)
                XCTAssertEqual(error.message!, "near \"BLAH\": syntax error")
                XCTAssertEqual(error.sql!, "BLAH")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `BLAH`: near \"BLAH\": syntax error")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
    
    func testDatabaseErrorThrownByUpdateStatementContainSQLAndBindings() {
        dbQueue.inDatabase { db in
            do {
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", bindings: [1, "Bobby"])
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, Int(SQLITE_CONSTRAINT))
                XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description, "SQLite error 19 with statement `INSERT INTO pets (masterId, name) VALUES (?, ?)` bindings [1, \"Bobby\"]: FOREIGN KEY constraint failed")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
    
    func testDatabaseErrorThrownBySelectStatementContainSQL() {
        dbQueue.inDatabase { db in
            do {
                let _ = try SelectStatement(database: db, sql: "SELECT * FROM blah", bindings: nil, unsafe: false)
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.code, 1)
                XCTAssertEqual(error.message!, "no such table: blah")
                XCTAssertEqual(error.sql!, "SELECT * FROM blah")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `SELECT * FROM blah`: no such table: blah")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
}
