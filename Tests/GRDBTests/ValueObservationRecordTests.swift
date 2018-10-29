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

private struct Player: FetchableRecord {
    var id: Int64
    var name: String
    
    init(row: Row) {
        self.id = row["id"]
        self.name = row["name"]
    }
    
    var row: Row {
        return ["id": id, "name": name]
    }
}

class ValueObservationRecordTests: GRDBTestCase {
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Player]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingAll(SQLRequest<Player>("SELECT * FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { players in
            results.append(players)
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
        XCTAssertEqual(results.map { $0.map { $0.row }}, [
            [],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]]])
    }
    
    func testAllWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Player]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 3
        
        var observation = ValueObservation.trackingAll(withUniquing: SQLRequest<Player>("SELECT * FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { players in
            results.append(players)
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
        XCTAssertEqual(results.map { $0.map { $0.row }}, [
            [],
            [["id":1, "name":"foo"]],
            [["id":1, "name":"foo"], ["id":2, "name":"bar"]]])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Player?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        var observation = ValueObservation.trackingOne(SQLRequest<Player>("SELECT * FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { player in
            results.append(player)
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
        XCTAssertEqual(results.map { $0.map { $0.row }}, [
            nil,
            ["id":1, "name":"foo"],
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
    
    func testOneWithUniquing() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Player?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingOne(withUniquing: SQLRequest<Player>("SELECT * FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { player in
            results.append(player)
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
        XCTAssertEqual(results.map { $0.map { $0.row }}, [
            nil,
            ["id":1, "name":"foo"],
            ["id":2, "name":"bar"],
            nil])
    }
}
