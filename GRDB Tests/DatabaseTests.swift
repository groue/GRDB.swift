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
            
            let dropTableStmt = try database.updateStatementWithQuery("DROP TABLE IF EXISTS persons")
            try dropTableStmt.executeUpdate()
            
            let createTableStmt = try database.updateStatementWithQuery("CREATE TABLE persons (name TEXT, age INT)")
            try createTableStmt.executeUpdate()
            
            let insert1Stmt = try database.updateStatementWithQuery("INSERT INTO persons (name, age) VALUES (?, ?)")
            insert1Stmt.bind("Arthur", atIndex: 1)
            insert1Stmt.bind(36, atIndex: 2)
            try insert1Stmt.executeUpdate()
            
            let insert2Stmt = try database.updateStatementWithQuery("INSERT INTO persons (name, age) VALUES (:name, :age)")
            insert2Stmt.bind("Beate", forKey: ":name")
            insert2Stmt.bind(37, forKey: ":age")
            try insert2Stmt.executeUpdate()
            
            let rows = try database.rowSequenceWithQuery("SELECT * FROM persons")
            for row in rows {
                let name = row.stringAtIndex(0)
                let age = row.intAtIndex(1)
                print("\(name): \(age)")
            }
        } catch let error as GRDB.Error {
            print("Error \(error._code), \(error.message)")
        } catch {
            
        }
    }
}
