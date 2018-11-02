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
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingAll(SQLRequest<Name>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { names in
            results.append(names)
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
        XCTAssertEqual(results.map { $0.map { $0.rawValue }}, [
            [],
            ["foo"],
            ["foo", "bar"],
            ["bar"]])
    }
    
    func testOne() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [Name?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 7
        
        var observation = ValueObservation.trackingOne(SQLRequest<Name>("SELECT name FROM t ORDER BY id DESC"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { name in
            results.append(name)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')")
            try db.execute("UPDATE t SET name = 'foo' WHERE id = 1")
            try db.inTransaction {
                try db.execute("INSERT INTO t (id, name) VALUES (2, 'bar')")
                try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
                try db.execute("DELETE FROM t WHERE id = 3")
                return .commit
            }
            try db.execute("DELETE FROM t")
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'baz')")
            try db.execute("UPDATE t SET name = NULL")
            try db.execute("DELETE FROM t")
            try db.execute("INSERT INTO t (id, name) VALUES (1, NULL)")
            try db.execute("UPDATE t SET name = 'qux'")
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
    
    func testAllOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute("CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
        
        var results: [[Name?]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 4
        
        var observation = ValueObservation.trackingAll(SQLRequest<Name?>("SELECT name FROM t ORDER BY id"))
        observation.extent = .databaseLifetime
        _ = try observation.start(in: dbQueue) { names in
            results.append(names)
            notificationExpectation.fulfill()
        }
        
        try dbQueue.inDatabase { db in
            try db.execute("INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
            try db.execute("UPDATE t SET name = 'foo' WHERE id = 1")     // =
            try db.inTransaction {                                       // +1
                try db.execute("INSERT INTO t (id, name) VALUES (2, NULL)")
                try db.execute("INSERT INTO t (id, name) VALUES (3, 'baz')")
                try db.execute("DELETE FROM t WHERE id = 3")
                return .commit
            }
            try db.execute("DELETE FROM t WHERE id = 1")                 // -1
        }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssertEqual(results.map { $0.map { $0?.rawValue }}, [
            [],
            ["foo"],
            ["foo", nil],
            [nil]])
    }
}
