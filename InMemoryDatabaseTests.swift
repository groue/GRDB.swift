//
//  InMemoryDatabaseTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 04/07/2015.
//  Copyright © 2015 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class InMemoryDatabaseTests : GRDBTestCase
{
    func testInMemoryDatabase() {
        assertNoError {
            let dbQueue = try DatabaseQueue()
            try dbQueue.inTransaction { db in
                try db.execute("CREATE TABLE foo (bar TEXT)")
                try db.execute("INSERT INTO foo (bar) VALUES ('baz')")
                let baz = db.fetchOne(String.self, "SELECT bar FROM foo")!
                XCTAssertEqual(baz, "baz")
                return .Rollback
            }
        }
    }
}
