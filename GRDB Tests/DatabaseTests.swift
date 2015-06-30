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
            insert1Stmt.reset()
            insert1Stmt.bind("Arthur no age", atIndex: 1)
            insert1Stmt.bind(nil, atIndex: 2)
            try insert1Stmt.executeUpdate()
            
            let insert2Stmt = try database.updateStatementWithQuery("INSERT INTO persons (name, age) VALUES (?, ?)")
            insert2Stmt.bind(["Zoe", 65])
            try insert2Stmt.executeUpdate()
            insert2Stmt.reset()
            insert2Stmt.bind(["Zoe no age", nil])
            try insert2Stmt.executeUpdate()
            
            let insert3Stmt = try database.updateStatementWithQuery("INSERT INTO persons (name, age) VALUES (:name, :age)")
            insert3Stmt.bind("Beate", forKey: ":name")
            insert3Stmt.bind(37, forKey: ":age")
            try insert3Stmt.executeUpdate()
            insert3Stmt.reset()
            insert3Stmt.bind("Beate no age", forKey: ":name")
            insert3Stmt.bind(nil, forKey: ":age")
            try insert3Stmt.executeUpdate()
            
            let insert4Stmt = try database.updateStatementWithQuery("INSERT INTO persons (name, age) VALUES (:name, :age)")
            insert4Stmt.bind([":name": "Crystel", ":age": 16])
            try insert4Stmt.executeUpdate()
            insert4Stmt.reset()
            insert4Stmt.bind([":name": "Crystel no age", ":age": nil])
            try insert4Stmt.executeUpdate()
            
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
