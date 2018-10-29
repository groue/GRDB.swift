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
        
        var observation = ValueObservation.forAll(SQLRequest<Row>("SELECT * FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            [],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]]])
    }
    
    func testAllWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.forAll(withUniquing: SQLRequest<Row>("SELECT * FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            [],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]]])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        var observation = ValueObservation.forOne(SQLRequest<Row>("SELECT * FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        try dbQueue.write {
            try $0.execute("DELETE FROM t")
        }

        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            nil,
            ["id":1, "name":"foo"],
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
    
    func testOneWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.forOne(withUniquing: SQLRequest<Row>("SELECT * FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try dbQueue.start(observation) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
        }
        try dbQueue.write {
            try $0.execute("UPDATE t SET name = 'foo' WHERE id = 1")
        }
        try dbQueue.write {
            try $0.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
        }
        try dbQueue.write {
            try $0.execute("DELETE FROM t")
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results, [
            nil,
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
}
