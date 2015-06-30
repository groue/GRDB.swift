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
            
            let dropTableStmt = try database.updateStatement("DROP TABLE IF EXISTS persons")
            try dropTableStmt.execute()
            
            let createTableStmt = try database.updateStatement("CREATE TABLE persons (name TEXT, age INT)")
            try createTableStmt.execute()
            
            let insert1Stmt = try database.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
            insert1Stmt.bind("Arthur", atIndex: 1)
            insert1Stmt.bind(36, atIndex: 2)
            try insert1Stmt.execute()
            insert1Stmt.reset()
            insert1Stmt.bind("Arthur no age", atIndex: 1)
            insert1Stmt.bind(nil, atIndex: 2)
            try insert1Stmt.execute()
            
            let insert2Stmt = try database.updateStatement("INSERT INTO persons (name, age) VALUES (?, ?)")
            insert2Stmt.bind(["Zoe", 65])
            try insert2Stmt.execute()
            insert2Stmt.reset()
            insert2Stmt.bind(["Zoe no age", nil])
            try insert2Stmt.execute()
            
            let insert3Stmt = try database.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
            insert3Stmt.bind("Beate", forKey: ":name")
            insert3Stmt.bind(37, forKey: ":age")
            try insert3Stmt.execute()
            insert3Stmt.reset()
            insert3Stmt.bind("Beate no age", forKey: ":name")
            insert3Stmt.bind(nil, forKey: ":age")
            try insert3Stmt.execute()
            
            let insert4Stmt = try database.updateStatement("INSERT INTO persons (name, age) VALUES (:name, :age)")
            insert4Stmt.bind([":name": "Crystel", ":age": 16])
            try insert4Stmt.execute()
            insert4Stmt.reset()
            insert4Stmt.bind([":name": "Crystel no age", ":age": nil])
            try insert4Stmt.execute()
            
            let rows = try database.selectStatement("SELECT * FROM persons")
            for row in rows {
                let name = row.stringAtIndex(0)
                let age = row.intAtIndex(1)
                print("\(name): \(age)")
                print("\(row.asDictionary)")
            }
        } catch let error as GRDB.Error {
            print("Error \(error._code), \(error.message)")
        } catch {
            
        }
    }
}
