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

class ValueObservationFetchTests: GRDBTestCase {
    func testRegionsAPI() {
        // single region
        _ = ValueObservation.tracking(DatabaseRegion(), fetch: { _ in })
        // variadic
        _ = ValueObservation.tracking(DatabaseRegion(), DatabaseRegion(), fetch: { _ in })
        // array
        _ = ValueObservation.tracking([DatabaseRegion()], fetch: { _ in })
    }
    
    func testFetch() throws {
        try assertValueObservation(
            ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            }),
            records: [0, 1, 1, 2],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
    }
    
    func testRemoveDuplicated() throws {
        try assertValueObservation(
            ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            }).removeDuplicates(),
            records: [0, 1, 2],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
    }
}
