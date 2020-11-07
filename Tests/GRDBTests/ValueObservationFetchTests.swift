import XCTest
import GRDB

class ValueObservationFetchTests: GRDBTestCase {
    func testFetch() throws {
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            },
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
            ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
                .removeDuplicates(),
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
