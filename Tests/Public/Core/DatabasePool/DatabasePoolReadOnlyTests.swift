//
//  DatabasePoolReadOnlyTests.swift
//  GRDB
//
//  Created by Gwendal Roué on 11/03/2016.
//  Copyright © 2016 Gwendal Roué. All rights reserved.
//

import XCTest
import GRDB

class DatabasePoolReadOnlyTests: GRDBTestCase {
    
    func testConcurrentRead() {
        assertNoError {
            let databaseFileName = "db.sqlite"
            
            // Create a non-WAL database:
            do {
                let dbQueue = try makeDatabaseQueue(databaseFileName)
                try dbQueue.inDatabase { db in
                    try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for _ in 0..<3 {
                        try db.execute("INSERT INTO items (id) VALUES (NULL)")
                    }
                }
            }
            
            // Open a read-only pool on that database:
            dbConfiguration.readonly = true
            let dbPool = try makeDatabasePool(databaseFileName)
            
            // Make sure the database is not in WAL mode
            let mode = String.fetchOne(dbPool, "PRAGMA journal_mode")!
            XCTAssertNotEqual(mode.lowercaseString, "wal")
            
            // Block 1                  Block 2
            // SELECT * FROM items      SELECT * FROM items
            // step                     step
            // >
            let s1 = dispatch_semaphore_create(0)
            //                          step
            //                          <
            let s2 = dispatch_semaphore_create(0)
            // step                     step
            // step                     end
            // end
            
            let block1 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s1)
                    dispatch_semaphore_wait(s2, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let block2 = { () in
                dbPool.read { db in
                    let generator = Row.fetch(db, "SELECT * FROM items").generate()
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_wait(s1, DISPATCH_TIME_FOREVER)
                    XCTAssertTrue(generator.next() != nil)
                    dispatch_semaphore_signal(s2)
                    XCTAssertTrue(generator.next() != nil)
                    XCTAssertTrue(generator.next() == nil)
                }
            }
            let queue = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
            dispatch_apply(2, queue) { index in
                [block1, block2][index]()
            }
        }
    }
}
