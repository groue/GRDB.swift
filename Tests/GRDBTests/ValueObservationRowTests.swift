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
    func testAll() throws {
        try assertValueObservation(
            SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id").observationForAll(),
            records: [
                [],
                [["id":1, "name":"foo"]],
                [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
                [["id":2, "name":"bar"]]],
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
            SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id DESC").observationForFirst(),
            records: [
                nil,
                ["id":1, "name":"foo"],
                ["id":2, "name":"bar"],
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
    
    func testFTS4Observation() throws {
        try assertValueObservation(
            SQLRequest<Row>(sql: "SELECT * FROM ft_documents").observationForAll(),
            records: [
                [],
                [["content":"foo"]]],
            setup: { db in
                try db.create(virtualTable: "ft_documents", using: FTS4())
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO ft_documents VALUES (?)", arguments: ["foo"])
        })
    }
    
    func testSynchronizedFTS4Observation() throws {
        try assertValueObservation(
            SQLRequest<Row>(sql: "SELECT * FROM ft_documents").observationForAll(),
            records: [
                [],
                [["content":"foo"]]],
            setup: { db in
                try db.create(table: "documents") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("content", .text)
                }
                try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                    t.synchronize(withTable: "documents")
                    t.column("content")
                }
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
        })
    }
    
    func testJoinedFTS4Observation() throws {
        try assertValueObservation(
            SQLRequest<Row>(sql: """
                SELECT document.* FROM document
                JOIN ft_document ON ft_document.rowid = document.id
                WHERE ft_document MATCH 'foo'
                """)
                .observationForAll(),
            records: [
                [],
                [["id":1]]],
            setup: { db in
                try db.create(table: "document") { t in
                    t.autoIncrementedPrimaryKey("id")
                }
                try db.create(virtualTable: "ft_document", using: FTS4()) { t in
                    t.column("content")
                }
        },
            recordedUpdates: { db in
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO document (id) VALUES (?)", arguments: [1])
                    try db.execute(sql: "INSERT INTO ft_document (rowid, content) VALUES (?, ?)", arguments: [1, "foo"])
                    return .commit
                }
        })
    }
}
