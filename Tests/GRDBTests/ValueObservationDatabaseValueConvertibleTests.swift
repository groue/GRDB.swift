import XCTest
#if GRDBCUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    #if GRDBCIPHER
        import SQLCipher
    #elseif SWIFT_PACKAGE
        import CSQLite
    #else
        import SQLite3
    #endif
    @testable import GRDB
#endif

private struct Name: DatabaseValueConvertible {
    var rawValue: String
    
    var databaseValue: DatabaseValue {
        return rawValue.databaseValue
    }
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Name? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return Name(rawValue: rawValue)
    }
}

class ValueObservationDatabaseValueConvertibleTests: GRDBTestCase {
    func testAllDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = ValueObservation.trackingAll(SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id"))
        let observer = try observation.start(in: dbQueue) { names in
            results.append(names)
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
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                [],
                ["foo"],
                ["foo", "bar"],
                ["bar"]])
        }
    }
    
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id").observationForAll()
        let observer = try observation.start(in: dbQueue) { names in
            results.append(names)
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
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                [],
                ["foo"],
                ["foo", "bar"],
                ["bar"]])
        }
    }
    
    func testOneDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        let observation = ValueObservation.trackingOne(SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id DESC"))
        let observer = try observation.start(in: dbQueue) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'baz')")
                try db.execute(sql: "UPDATE t SET name = NULL")
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, NULL)")
                try db.execute(sql: "UPDATE t SET name = 'qux'")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                nil,
                "foo",
                "bar",
                nil,
                "baz",
                nil,
                "qux"])
        }
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        let observation = SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id DESC").observationForFirst()
        let observer = try observation.start(in: dbQueue) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'baz')")
                try db.execute(sql: "UPDATE t SET name = NULL")
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, NULL)")
                try db.execute(sql: "UPDATE t SET name = 'qux'")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                nil,
                "foo",
                "bar",
                nil,
                "baz",
                nil,
                "qux"])
        }
    }
    
    func testAllOptionalDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name?]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = ValueObservation.trackingAll(SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id"))
        let observer = try observation.start(in: dbQueue) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, NULL)")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.map { $0.map { $0?.rawValue }}, [
                [],
                ["foo"],
                ["foo", nil],
                [nil]])
        }
    }
    
    func testAllOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name?]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        let observation = SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id").observationForAll()
        let observer = try observation.start(in: dbQueue) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, NULL)")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.map { $0.map { $0?.rawValue }}, [
                [],
                ["foo"],
                ["foo", nil],
                [nil]])
        }
    }
    
    func testOneOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        let observation = SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id DESC").observationForFirst()
        let observer = try observation.start(in: dbQueue) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'baz')")
                try db.execute(sql: "UPDATE t SET name = NULL")
                try db.execute(sql: "DELETE FROM t")
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, NULL)")
                try db.execute(sql: "UPDATE t SET name = 'qux'")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                nil,
                "foo",
                "bar",
                nil,
                "baz",
                nil,
                "qux"])
        }
    }
    
    func testViewOptimization() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write {
            try $0.execute(sql: """
                CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
                CREATE VIEW v AS SELECT * FROM t
                """)
        }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        // Test that view v is included in the request region
        let request = SQLRequest<Name>(sql: "SELECT name FROM v ORDER BY id")
        try dbQueue.inDatabase { db in
            let region = try request.databaseRegion(db)
            XCTAssertEqual(region.description, "t(id,name),v(id,name)")
        }
        
        // Test that view v is not included in the observed region.
        // This optimization helps observation of views that feed from a
        // single table.
        let observation = request.observationForAll()
        let observer = try observation.start(in: dbQueue) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        let token = observer as! ValueObserverToken<ValueReducers.AllValues<Name>> // Non-public implementation detail
        XCTAssertEqual(token.observer.observedRegion.description, "t(id,name)") // view is not tracked
        try withExtendedLifetime(observer) {
            // Test view observation
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
            XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
                [],
                ["foo"],
                ["foo", "bar"],
                ["bar"]])
        }
    }
}
