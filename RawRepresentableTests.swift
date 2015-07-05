//
//  RawRepresentableTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 05/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

protocol IntRawRepresentableSQLiteValueConvertible : SQLiteValueConvertible {
    typealias RawValue = Int
    var rawValue: Int { get }
    init?(rawValue: Int)
}

extension IntRawRepresentableSQLiteValueConvertible {
    var sqliteValue: SQLiteValue {
        return .Integer(Int64(rawValue))
    }
    init?(sqliteValue: SQLiteValue) {
        if let int = Int(sqliteValue: sqliteValue) {
            self.init(rawValue: int)
        } else {
            return nil
        }
    }
}

enum Color : Int {
    case Red
    case White
    case Rose
}

extension Color : IntRawRepresentableSQLiteValueConvertible { }

class RawRepresentableTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPersons") { db in
            try db.execute("CREATE TABLE wines (color INTEGER)")
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
}
