import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class DatabaseSchedulerTests: GRDBTestCase {
    
    func testDatabaseQueueFromDatabaseQueue() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue("db1")
            let dbQueue2 = try makeDatabaseQueue("db2")
            try dbQueue1.inDatabase { db1 in
                try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db1.execute("INSERT INTO items (id) VALUES (NULL)")
                try dbQueue2.inDatabase { db2 in
                    try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for row in Row.fetch(db1, "SELECT * FROM items") {
                        try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row.value(named: "id")])
                    }
                }
            }
            let count = dbQueue2.inDatabase { db2 in
                Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
            }
            XCTAssertEqual(count, 1)
        }
    }
    
    func testDatabaseQueueFromDatabasePool() {
        assertNoError {
            let dbPool1 = try makeDatabasePool("db1")
            let dbQueue2 = try makeDatabaseQueue("db2")
            try dbPool1.write { db1 in
                try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db1.execute("INSERT INTO items (id) VALUES (NULL)")
                try dbQueue2.inDatabase { db2 in
                    try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for row in Row.fetch(db1, "SELECT * FROM items") {
                        try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row.value(named: "id")])
                    }
                }
            }
            let count = dbQueue2.inDatabase { db2 in
                Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
            }
            XCTAssertEqual(count, 1)
        }
    }
    
    func testDatabasePoolFromDatabaseQueue() {
        assertNoError {
            let dbQueue1 = try makeDatabaseQueue("db1")
            let dbPool2 = try makeDatabasePool("db2")
            try dbQueue1.inDatabase { db1 in
                try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db1.execute("INSERT INTO items (id) VALUES (NULL)")
                try dbPool2.write { db2 in
                    try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for row in Row.fetch(db1, "SELECT * FROM items") {
                        try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row.value(named: "id")])
                    }
                }
            }
            let count = dbPool2.read { db2 in
                Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
            }
            XCTAssertEqual(count, 1)
        }
    }
    
    func testDatabasePoolFromDatabasePool() {
        assertNoError {
            let dbPool1 = try makeDatabasePool("db1")
            let dbPool2 = try makeDatabasePool("db2")
            try dbPool1.write { db1 in
                try db1.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                try db1.execute("INSERT INTO items (id) VALUES (NULL)")
                try dbPool2.write { db2 in
                    try db2.execute("CREATE TABLE items (id INTEGER PRIMARY KEY)")
                    for row in Row.fetch(db1, "SELECT * FROM items") {
                        try db2.execute("INSERT INTO items (id) VALUES (?)", arguments: [row.value(named: "id")])
                    }
                }
            }
            let count = dbPool2.write { db2 in
                Int.fetchOne(db2, "SELECT COUNT(*) FROM items")!
            }
            XCTAssertEqual(count, 1)
        }
    }
}
