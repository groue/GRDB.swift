//
//  RowTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 04/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class RowTests: GRDBTestCase {
    
    func testRowAsSequence() {
        assertNoError {
            let dbQueue = DatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE texts (a TEXT, b TEXT, c TEXT)")
                try db.execute("INSERT INTO texts (a,b,c) VALUES ('foo', 'bar', 'baz')")
                let row = db.fetchOneRow("SELECT * FROM texts")!
                
                var columnNames = [String]()
                var texts = [String]()
                for (columnName, sqliteValue) in row {
                    columnNames.append(columnName)
                    texts.append(sqliteValue.value()! as String)
                }
                
                XCTAssertEqual(columnNames, ["a", "b", "c"])
                XCTAssertEqual(texts, ["foo", "bar", "baz"])
                
                return .Rollback
            }
        }

    }
}
