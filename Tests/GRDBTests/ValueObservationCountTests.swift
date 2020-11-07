import XCTest
import GRDB

class ValueObservationCountTests: GRDBTestCase {
    func testCount() throws {
        struct T: TableRecord { }
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(T.fetchCount),
            records: [0, 1, 1, 2, 3, 4],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "DELETE FROM t WHERE id = 1")
                    return .commit
                }
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
    }
    
    func testCountWithRemoveDuplicates() throws {
        struct T: TableRecord { }
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(T.fetchCount).removeDuplicates(),
            records: [0, 1, 2, 3, 4],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.inTransaction {
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "DELETE FROM t WHERE id = 1")
                    return .commit
                }
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
    }
}
