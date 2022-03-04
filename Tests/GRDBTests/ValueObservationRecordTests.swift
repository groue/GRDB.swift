import XCTest
import GRDB

private struct Player: Equatable {
    var id: Int64
    var name: String
}

extension Player: TableRecord, FetchableRecord {
    static let databaseTableName = "t"
    init(row: Row) throws {
        try self.init(id: row["id"], name: row["name"])
    }
}

class ValueObservationRecordTests: GRDBTestCase {
    func testAll() throws {
        let request = SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll),
            records: [
                [],
                [Player(id: 1, name: "foo")],
                [Player(id: 1, name: "foo")],
                [Player(id: 1, name: "foo"), Player(id: 2, name: "bar")],
                [Player(id: 2, name: "bar")]],
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
        
        // The fundamental technique for removing duplicates of non-Equatable types
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { try Row.fetchAll($0, request) }
                .removeDuplicates()
                .map { try $0.map(Player.init(row:)) },
            records: [
                [],
                [Player(id: 1, name: "foo")],
                [Player(id: 1, name: "foo"), Player(id: 2, name: "bar")],
                [Player(id: 2, name: "bar")]],
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
        let request = SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id DESC")
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne),
            records: [
                nil,
                Player(id: 1, name: "foo"),
                Player(id: 1, name: "foo"),
                Player(id: 2, name: "bar"),
                nil,
                Player(id: 3, name: "toto")],
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
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'toto')")
        })
        
        // The fundamental technique for removing duplicates of non-Equatable types
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { try Row.fetchOne($0, request) }
                .removeDuplicates()
                .map { try $0.map(Player.init(row:)) },
            records: [
                nil,
                Player(id: 1, name: "foo"),
                Player(id: 2, name: "bar"),
                nil,
                Player(id: 3, name: "toto")],
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
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'toto')")
        })
    }
}
