import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher // @testable so that we can test SchedulingWatchdog
#elseif GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite // @testable so that we can test SchedulingWatchdog
#else
    @testable import GRDB // @testable so that we can test SchedulingWatchdog
#endif

class SchedulingWatchdogTests: GRDBTestCase {
    
    func testSchedulingWatchdog() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "db1")
        let dbQueue2 = try makeDatabaseQueue(filename: "db2")
        let dbQueue3 = try makeDatabaseQueue(filename: "db3")
        
        var db1: Database! = nil
        var db2: Database! = nil
        var db3: Database! = nil
        dbQueue1.inDatabase { db1 = $0 }
        dbQueue2.inDatabase { db2 = $0 }
        dbQueue3.inDatabase { db3 = $0 }
        
        XCTAssertFalse(SchedulingWatchdog.allows(db1))
        XCTAssertFalse(SchedulingWatchdog.allows(db2))
        XCTAssertFalse(SchedulingWatchdog.allows(db3))
        dbQueue1.inDatabase { _ in
            XCTAssertTrue(SchedulingWatchdog.allows(db1))
            XCTAssertFalse(SchedulingWatchdog.allows(db2))
            XCTAssertFalse(SchedulingWatchdog.allows(db3))
            dbQueue2.inDatabase { _ in
                XCTAssertTrue(SchedulingWatchdog.allows(db1))
                XCTAssertTrue(SchedulingWatchdog.allows(db2))
                XCTAssertFalse(SchedulingWatchdog.allows(db3))
                dbQueue3.inDatabase { _ in
                    XCTAssertTrue(SchedulingWatchdog.allows(db1))
                    XCTAssertTrue(SchedulingWatchdog.allows(db2))
                    XCTAssertTrue(SchedulingWatchdog.allows(db3))
                }
                XCTAssertTrue(SchedulingWatchdog.allows(db1))
                XCTAssertTrue(SchedulingWatchdog.allows(db2))
                XCTAssertFalse(SchedulingWatchdog.allows(db3))
            }
            XCTAssertTrue(SchedulingWatchdog.allows(db1))
            XCTAssertFalse(SchedulingWatchdog.allows(db3))
            XCTAssertFalse(SchedulingWatchdog.allows(db2))
        }
        XCTAssertFalse(SchedulingWatchdog.allows(db1))
        XCTAssertFalse(SchedulingWatchdog.allows(db2))
        XCTAssertFalse(SchedulingWatchdog.allows(db3))
    }

    func testDatabaseQueueFromDatabaseQueue() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "db1")
        let dbQueue2 = try makeDatabaseQueue(filename: "db2")
        try dbQueue1.inDatabase { db1 in
            try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute("INSERT INTO items (id) VALUES (NULL)")
            try dbQueue2.inDatabase { db2 in
                try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row["id"]])
                }
            }
        }
        let count = try dbQueue2.inDatabase { db2 in
            try Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabaseQueueFromDatabasePool() throws {
        let dbPool1 = try makeDatabasePool(filename: "db1")
        let dbQueue2 = try makeDatabaseQueue(filename: "db2")
        try dbPool1.write { db1 in
            try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute("INSERT INTO items (id) VALUES (NULL)")
            try dbQueue2.inDatabase { db2 in
                try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row["id"]])
                }
            }
        }
        let count = try dbQueue2.inDatabase { db2 in
            try Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabasePoolFromDatabaseQueue() throws {
        let dbQueue1 = try makeDatabaseQueue(filename: "db1")
        let dbPool2 = try makeDatabasePool(filename: "db2")
        try dbQueue1.inDatabase { db1 in
            try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute("INSERT INTO items (id) VALUES (NULL)")
            try dbPool2.write { db2 in
                try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row["id"]])
                }
            }
        }
        let count = try dbPool2.read { db2 in
            try Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }

    func testDatabasePoolFromDatabasePool() throws {
        let dbPool1 = try makeDatabasePool(filename: "db1")
        let dbPool2 = try makeDatabasePool(filename: "db2")
        try dbPool1.write { db1 in
            try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
            try db1.execute("INSERT INTO items (id) VALUES (NULL)")
            try dbPool2.write { db2 in
                try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                let rows = try Row.fetchCursor(db1, "SELECT * FROM items")
                while let row = try rows.next() {
                    try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row["id"]])
                }
            }
        }
        let count = try dbPool2.write { db2 in
            try Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
        }
        XCTAssertEqual(count, 1)
    }
}
