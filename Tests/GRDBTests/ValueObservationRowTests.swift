import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    #if SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    import GRDB
#endif

class ValueObservationRowTests: GRDBTestCase {
    func testAllDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = ValueObservation.trackingAll(SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id"))
        let observer = try observation.start(in: dbQueue) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
                [],
                [["id":1, "name":"foo"]],
                [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
                [["id":2, "name":"bar"]]])
        }
    }
    
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id").observationForAll()
        let observer = try observation.start(in: dbQueue) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
                [],
                [["id":1, "name":"foo"]],
                [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
                [["id":2, "name":"bar"]]])
        }
    }
    
    func testOneDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = ValueObservation.trackingOne(SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id DESC"))
        let observer = try observation.start(in: dbQueue) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")                              // -1
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            nil,
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id DESC").observationForFirst()
        let observer = try observation.start(in: dbQueue) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")                              // -1
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            nil,
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
}
