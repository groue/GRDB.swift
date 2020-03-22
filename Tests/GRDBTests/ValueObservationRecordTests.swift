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

private struct Player: Equatable {
    var id: Int64
    var name: String
}

extension Player: TableRecord, FetchableRecord {
    static let databaseTableName = "t"
    init(row: Row) {
        self.init(id: row["id"], name: row["name"])
    }
}

class ValueObservationRecordTests: GRDBTestCase {
    func testAll() throws {
        try assertValueObservation(
            SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id").observationForAll(),
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
    
    func testTableRecordStaticAll() throws {
        try assertValueObservation(
            Player.observationForAll(),
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
        try assertValueObservation(
            SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id DESC").observationForFirst(),
            records: [
                nil,
                Player(id: 1, name: "foo"),
                Player(id: 2, name: "bar"),
                nil],
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
        })
    }
}
