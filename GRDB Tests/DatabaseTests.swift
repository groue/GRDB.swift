//
//  DatabaseTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 30/06/2015.
//  Copyright © 2015 Stephen Celis. All rights reserved.
//

import XCTest
import GRDB

class DatabaseTests: XCTestCase {
    
    func testDatabase() {
        do {
            let database = try Database(path: "/tmp/GRDB.sqlite")
            
            let dropTableStmt = try database.updateStatementWithQuery("DROP TABLE IF EXISTS toto")
            try dropTableStmt.executeUpdate()
            
            let createTableStmt = try database.updateStatementWithQuery("CREATE TABLE toto (tata INT)")
            try createTableStmt.executeUpdate()
            
            let insert1Stmt = try database.updateStatementWithQuery("INSERT INTO toto (tata) VALUES (1)")
            try insert1Stmt.executeUpdate()
            
            let insert2Stmt = try database.updateStatementWithQuery("INSERT INTO toto (tata) VALUES (2)")
            try insert2Stmt.executeUpdate()
            
            let rows = try database.rowSequenceWithQuery("SELECT * FROM toto")
            for row in rows {
                let tata = row.intAtIndex(0)
                print(tata)
            }
        } catch let error as GRDB.Error {
            print("Error \(error._code), \(error.message)")
        } catch {
            
        }
    }
}
