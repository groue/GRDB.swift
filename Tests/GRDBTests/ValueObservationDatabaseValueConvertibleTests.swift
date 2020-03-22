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

private struct Name: DatabaseValueConvertible, Equatable {
    var rawValue: String
    
    var databaseValue: DatabaseValue { rawValue.databaseValue }
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Name? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return Name(rawValue: rawValue)
    }
}

class ValueObservationDatabaseValueConvertibleTests: GRDBTestCase {
    func testAll() throws {
        try assertValueObservation(
            SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id").observationForAll(),
            records: [
                [],
                [Name(rawValue: "foo")],
                [Name(rawValue: "foo"), Name(rawValue: "bar")],
                [Name(rawValue: "bar")]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")
        })
    }
    
    func testOne() throws {
        try assertValueObservation(
            SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id DESC").observationForFirst(),
            records: [
                nil,
                Name(rawValue: "foo"),
                Name(rawValue: "bar"),
                nil,
                Name(rawValue: "baz"),
                nil,
                Name(rawValue: "qux")],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        },
            recordedUpdates: { db in
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
        })
    }
    
    func testAllOptional() throws {
        try assertValueObservation(
            SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id").observationForAll(),
            records: [
                [],
                [Name(rawValue: "foo")],
                [Name(rawValue: "foo"), nil],
                [nil]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')")
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, NULL)")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")
        })
    }
    
    func testOneOptional() throws {
        try assertValueObservation(
            SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id DESC").observationForFirst(),
            records: [
                nil,
                Name(rawValue: "foo"),
                Name(rawValue: "bar"),
                nil,
                Name(rawValue: "baz"),
                nil,
                Name(rawValue: "qux")],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)")
        },
            recordedUpdates: { db in
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
        })
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
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { names in
                results.append(names)
                notificationExpectation.fulfill()
        })
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
            XCTAssertEqual(results.map { $0.map(\.rawValue)}, [
                [],
                ["foo"],
                ["foo", "bar"],
                ["bar"]])
        }
    }
}
