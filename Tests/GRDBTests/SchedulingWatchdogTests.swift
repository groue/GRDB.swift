import XCTest
@testable import GRDB

class SchedulingWatchdogTests: GRDBTestCase {
    
    func testSchedulingWatchdog() throws {
        let dbQueue1 = try makeDatabaseQueue()
        let dbQueue2 = try makeDatabaseQueue()
        let dbQueue3 = try makeDatabaseQueue()
        
        var db1: Database! = nil
        var db2: Database! = nil
        var db3: Database! = nil
        dbQueue1.inDatabase { db1 = $0 }
        dbQueue2.inDatabase { db2 = $0 }
        dbQueue3.inDatabase { db3 = $0 }
        
        XCTAssertNil(SchedulingWatchdog.current)
        dbQueue1.inDatabase { _ in
            XCTAssertTrue(SchedulingWatchdog.current!.allows(db1))
            XCTAssertFalse(SchedulingWatchdog.current!.allows(db2))
            XCTAssertFalse(SchedulingWatchdog.current!.allows(db3))
            dbQueue2.inDatabase { _ in
                XCTAssertTrue(SchedulingWatchdog.current!.allows(db1))
                XCTAssertTrue(SchedulingWatchdog.current!.allows(db2))
                XCTAssertFalse(SchedulingWatchdog.current!.allows(db3))
                dbQueue3.inDatabase { _ in
                    XCTAssertTrue(SchedulingWatchdog.current!.allows(db1))
                    XCTAssertTrue(SchedulingWatchdog.current!.allows(db2))
                    XCTAssertTrue(SchedulingWatchdog.current!.allows(db3))
                }
                XCTAssertTrue(SchedulingWatchdog.current!.allows(db1))
                XCTAssertTrue(SchedulingWatchdog.current!.allows(db2))
                XCTAssertFalse(SchedulingWatchdog.current!.allows(db3))
            }
            XCTAssertTrue(SchedulingWatchdog.current!.allows(db1))
            XCTAssertFalse(SchedulingWatchdog.current!.allows(db3))
            XCTAssertFalse(SchedulingWatchdog.current!.allows(db2))
        }
        XCTAssertNil(SchedulingWatchdog.current)
    }

    func testDatabaseQueueFromDatabaseQueue() throws {
        let dbQueue1 = try makeDatabaseQueue()
        let dbQueue2 = try makeDatabaseQueue()
        try dbQueue1.inDatabase { db1 in
            try db1.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            try dbQueue2.inDatabase { db2 in
                try db2.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, sql: "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute(sql: "INSERT INTO items (id) VALUES (?)", arguments: [row.databaseValue(forColumn: "id")])
                }
            }
        }
        let count = try dbQueue2.inDatabase { db2 in
            try Int.fetchOne(db2, sql: "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabaseQueueFromDatabasePool() throws {
        let dbPool1 = try makeDatabasePool()
        let dbQueue2 = try makeDatabaseQueue()
        try dbPool1.write { db1 in
            try db1.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            try dbQueue2.inDatabase { db2 in
                try db2.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, sql: "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute(sql: "INSERT INTO items (id) VALUES (?)", arguments: [row.databaseValue(forColumn: "id")])
                }
            }
        }
        let count = try dbQueue2.inDatabase { db2 in
            try Int.fetchOne(db2, sql: "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabasePoolFromDatabaseQueue() throws {
        let dbQueue1 = try makeDatabaseQueue()
        let dbPool2 = try makeDatabasePool()
        try dbQueue1.inDatabase { db1 in
            try db1.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            try dbPool2.write { db2 in
                try db2.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, sql: "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute(sql: "INSERT INTO items (id) VALUES (?)", arguments: [row.databaseValue(forColumn: "id")])
                }
            }
        }
        let count = try dbPool2.read { db2 in
            try Int.fetchOne(db2, sql: "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabasePoolFromDatabasePool() throws {
        let dbPool1 = try makeDatabasePool()
        let dbPool2 = try makeDatabasePool()
        try dbPool1.write { db1 in
            try db1.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute(sql: "INSERT INTO items (id) VALUES (NULL)")
            try dbPool2.write { db2 in
                try db2.execute(sql: "CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, sql: "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute(sql: "INSERT INTO items (id) VALUES (?)", arguments: [row.databaseValue(forColumn: "id")])
                }
            }
        }
        let count = try dbPool2.write { db2 in
            try Int.fetchOne(db2, sql: "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }
}
