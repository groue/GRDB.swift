import XCTest
@testable import GRDB

private struct Name: DatabaseValueConvertible, Equatable, CustomDebugStringConvertible {
    var rawValue: String
    
    var databaseValue: DatabaseValue { rawValue.databaseValue }
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Name? {
        guard let rawValue = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return Name(rawValue: rawValue)
    }
    
    var debugDescription: String { rawValue }
}

class ValueObservationDatabaseValueConvertibleTests: GRDBTestCase {
    func testAll() throws {
        let request = SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll),
            records: [
                [],
                [Name(rawValue: "foo")],
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
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll).removeDuplicates(),
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
        let request = SQLRequest<Name>(sql: "SELECT name FROM t ORDER BY id DESC")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne),
            records: [
                nil,
                Name(rawValue: "foo"),
                Name(rawValue: "foo"),
                Name(rawValue: "bar"),
                nil,
                Name(rawValue: "baz"),
                nil,
                nil,
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
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne).removeDuplicates(),
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
        let request = SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll),
            records: [
                [],
                [Name(rawValue: "foo")],
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
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll).removeDuplicates(),
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
        let request = SQLRequest<Name?>(sql: "SELECT name FROM t ORDER BY id DESC")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne),
            records: [
                nil,
                Name(rawValue: "foo"),
                Name(rawValue: "foo"),
                Name(rawValue: "bar"),
                nil,
                Name(rawValue: "baz"),
                nil,
                nil,
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
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne).removeDuplicates(),
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
}
