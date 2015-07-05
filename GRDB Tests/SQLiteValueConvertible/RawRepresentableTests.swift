//
//  RawRepresentableTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 05/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

enum Color : Int {
    case Red
    case White
    case Rose
}

enum Grape : String {
    case Chardonnay = "Chardonnay"
    case Merlot = "Merlot"
    case Riesling = "Riesling"
}

extension Color : SQLiteIntRepresentable { }
extension Grape : SQLiteStringRepresentable { }

class RawRepresentableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE wines (grape TEXT, color INTEGER)")
        }
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    func testColor() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for color in [Color.Red, Color.White, Color.Rose] {
                        try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [color])
                    }
                    try db.execute("INSERT INTO wines (color) VALUES (?)", bindings: [4])
                }
                
                do {
                    let rows = db.fetchAllRows("SELECT color FROM wines ORDER BY color")
                    let colors = rows.map { $0.value(atIndex: 0) as Color? }
                    XCTAssertEqual(colors[0]!, Color.Red)
                    XCTAssertEqual(colors[1]!, Color.White)
                    XCTAssertEqual(colors[2]!, Color.Rose)
                    XCTAssertTrue(colors[3] == nil)
                }
                
                do {
                    let colors = db.fetchAll(Color.self, "SELECT color FROM wines ORDER BY color")
                    XCTAssertEqual(colors[0]!, Color.Red)
                    XCTAssertEqual(colors[1]!, Color.White)
                    XCTAssertEqual(colors[2]!, Color.Rose)
                    XCTAssertTrue(colors[3] == nil)
                }
                
                return .Rollback
            }
        }
    }
    
    func testGrape() {
        assertNoError {
            try dbQueue.inTransaction { db in
                
                do {
                    for grape in [Grape.Chardonnay, Grape.Merlot, Grape.Riesling] {
                        try db.execute("INSERT INTO wines (grape) VALUES (?)", bindings: [grape])
                    }
                    try db.execute("INSERT INTO wines (grape) VALUES (?)", bindings: ["Syrah"])
                }
                
                do {
                    let rows = db.fetchAllRows("SELECT grape FROM wines ORDER BY grape")
                    let grapes = rows.map { $0.value(atIndex: 0) as Grape? }
                    XCTAssertEqual(grapes[0]!, Grape.Chardonnay)
                    XCTAssertEqual(grapes[1]!, Grape.Merlot)
                    XCTAssertEqual(grapes[2]!, Grape.Riesling)
                    XCTAssertTrue(grapes[3] == nil)
                }
                
                do {
                    let grapes = db.fetchAll(Grape.self, "SELECT grape FROM wines ORDER BY grape")
                    XCTAssertEqual(grapes[0]!, Grape.Chardonnay)
                    XCTAssertEqual(grapes[1]!, Grape.Merlot)
                    XCTAssertEqual(grapes[2]!, Grape.Riesling)
                    XCTAssertTrue(grapes[3] == nil)
                }
                
                return .Rollback
            }
        }
    }
}
