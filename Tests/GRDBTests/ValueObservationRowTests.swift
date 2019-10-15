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
    
    func testFTS4Observation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(virtualTable: "ft_documents", using: FTS4())
        }
        
        var rows: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = SQLRequest<Row>(sql: "SELECT * FROM ft_documents")
        let observation = ValueObservation.tracking(value: request.fetchAll)
        let observer = observation.start(
            in: dbQueue,
            onError: { error in
                XCTFail("unexpected error: \(error)")
        },
            onChange: {
                rows.append($0)
                notificationExpectation.fulfill()
        })
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO ft_documents VALUES (?)", arguments: ["foo"])
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(rows, [[], [["content":"foo"]]])
        }
    }
    
    func testSynchronizedFTS4Observation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "documents") { t in
                t.column("id", .integer).primaryKey()
                t.column("content", .text)
            }
            try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                t.synchronize(withTable: "documents")
                t.column("content")
            }
        }
        
        var rows: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = SQLRequest<Row>(sql: "SELECT * FROM ft_documents")
        let observation = ValueObservation.tracking(value: request.fetchAll)
        let observer = observation.start(
            in: dbQueue,
            onError: { error in
                XCTFail("unexpected error: \(error)")
        },
            onChange: {
                rows.append($0)
                notificationExpectation.fulfill()
        })
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(rows, [[], [["content":"foo"]]])
        }
    }
    
    func testJoinedFTS4Observation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "document") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(virtualTable: "ft_document", using: FTS4()) { t in
                t.column("content")
            }
        }
        
        var rows: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = SQLRequest<Row>(sql: """
            SELECT document.* FROM document
            JOIN ft_document ON ft_document.rowid = document.id
            WHERE ft_document MATCH 'foo'
            """)
        let observation = ValueObservation.tracking(value: request.fetchAll)
        let observer = observation.start(
            in: dbQueue,
            onError: { error in
                XCTFail("unexpected error: \(error)")
        },
            onChange: {
                rows.append($0)
                notificationExpectation.fulfill()
        })
        try withExtendedLifetime(observer) {
            try dbQueue.write { db in
                try db.execute(sql: "INSERT INTO document (id) VALUES (?)", arguments: [1])
                try db.execute(sql: "INSERT INTO ft_document (rowid, content) VALUES (?, ?)", arguments: [1, "foo"])
            }
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(rows, [[], [["id":1]]])
        }
    }
}
