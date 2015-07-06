//
//  SQLiteErrorTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 06/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
@testable import GRDB

class SQLiteErrorTests: GRDBTestCase {
    
    func testSQLiteErrorThrownByUpdateStatementContainSQL() {
        dbQueue.inDatabase { db in
            do {
                try db.updateStatement("BLAH")
                XCTFail()
            } catch let error as SQLiteError {
                XCTAssertEqual(error.code, 1)
                XCTAssertEqual(error.message!, "near \"BLAH\": syntax error")
                XCTAssertEqual(error.sql!, "BLAH")
                XCTAssertEqual(error.description, "SQLite error 1 with statement `BLAH`: near \"BLAH\": syntax error")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
    
    func testSQLiteErrorThrownByUpdateStatementContainSQLAndBindings() {
        dbQueue.inDatabase { db in
            do {
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY)")
                try db.execute("CREATE TABLE pets (masterId INTEGER NOT NULL REFERENCES persons(id), name TEXT)")
                try db.execute("INSERT INTO pets (masterId, name) VALUES (?, ?)", bindings: [1, "Bobby"])
                XCTFail()
            } catch let error as SQLiteError {
                XCTAssertEqual(error.code, Int(SQLITE_CONSTRAINT))
                XCTAssertEqual(error.message!, "FOREIGN KEY constraint failed")
                XCTAssertEqual(error.sql!, "INSERT INTO pets (masterId, name) VALUES (?, ?)")
                XCTAssertEqual(error.description, "SQLite error 19 with statement `INSERT INTO pets (masterId, name) VALUES (?, ?)` bindings [1, \"Bobby\"]: FOREIGN KEY constraint failed")
            } catch {
                XCTFail("\(error)")
            }
        }
    }
    
    func testSQLiteErrorThrownBySelectStatementContainSQL() {
        dbQueue.inDatabase { db in
            do {
                let _ = try SelectStatement(database: db, sql: "SELECT * FROM blah", bindings: nil, unsafe: false)
                XCTFail()
            } catch let error as SQLiteError {
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
