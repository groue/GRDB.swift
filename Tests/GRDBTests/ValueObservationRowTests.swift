import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingAll(SQLRequest<Row>("SELECT * FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
            try db.execute("UPDATE t SET name = 'foo' WHERE id = 1")     // =
            try db.inTransaction {                                       // +1
                try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
                try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
                try db.execute("DELETE FROM t WHERE id = 3")
                return .commit
            }
            try db.execute("DELETE FROM t WHERE id = 1")                 // -1
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            [],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
            [["id":2, "name":"bar"]]])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingOne(SQLRequest<Row>("SELECT * FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
            try db.execute("UPDATE t SET name = 'foo' WHERE id = 1")     // =
            try db.inTransaction {                                       // +1
                try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
                try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
                try db.execute("DELETE FROM t WHERE id = 3")
                return .commit
            }
            try db.execute("DELETE FROM t")                              // -1
        }

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            nil,
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
}
