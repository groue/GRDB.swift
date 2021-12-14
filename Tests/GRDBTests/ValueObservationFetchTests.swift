import XCTest
import GRDB

class ValueObservationFetchTests: GRDBTestCase {
    func testFetch() throws {
        // Count
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
        
        // Select rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchAll($0, sql: "SELECT id FROM t ORDER BY id")
            },
            records: [[], [1], [1], [1, 2]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
        
        // Select non-rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try String.fetchAll($0, sql: "SELECT name FROM t ORDER BY name")
            },
            records: [[], ["Arthur"], ["Arthur", "Barbara"]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Arthur')")
                try db.execute(sql: "UPDATE t SET id = id") // does not trigger the observation
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Barbara')")
        })
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/954
    func testCaseInsensitivityForTable() throws {
        // Count
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            },
            records: [0, 1, 1, 2],
            setup: { db in
                try db.execute(sql: "CREATE TABLE T(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
        
        // Select rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchAll($0, sql: "SELECT id FROM t ORDER BY id")
            },
            records: [[], [1], [1], [1, 2]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE T(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
        
        // Select non-rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try String.fetchAll($0, sql: "SELECT name FROM t ORDER BY name")
            },
            records: [[], ["Arthur"], ["Arthur", "Barbara"]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE T(id INTEGER PRIMARY KEY, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Arthur')")
                try db.execute(sql: "UPDATE t SET id = id") // does not trigger the observation
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Barbara')")
        })
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/954
    func testCaseInsensitivityForFetch() throws {
        // Count
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM T")!
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
        
        // Select rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchAll($0, sql: "SELECT ID FROM T ORDER BY ID")
            },
            records: [[], [1], [1], [1, 2]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
        })
        
        // Select non-rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try String.fetchAll($0, sql: "SELECT NAME FROM T ORDER BY NAME")
            },
            records: [[], ["Arthur"], ["Arthur", "Barbara"]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Arthur')")
                try db.execute(sql: "UPDATE t SET id = id") // does not trigger the observation
                try db.execute(sql: "INSERT INTO t (name) VALUES ('Barbara')")
        })
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/954
    func testCaseInsensitivityForUpdates() throws {
        // Count
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            },
            records: [0, 1, 1, 2],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
                try db.execute(sql: "UPDATE T SET ID = ID")
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
        })
        
        // Select rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try Int.fetchAll($0, sql: "SELECT id FROM t ORDER BY id")
            },
            records: [[], [1], [1], [1, 2]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
                try db.execute(sql: "UPDATE T SET ID = ID")
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
        })
        
        // Select non-rowid
        try assertValueObservation(
            ValueObservation.trackingConstantRegion {
                try String.fetchAll($0, sql: "SELECT name FROM t ORDER BY name")
            },
            records: [[], ["Arthur"], ["Arthur", "Barbara"]],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY, name TEXT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO T (NAME) VALUES ('Arthur')")
                try db.execute(sql: "UPDATE T SET ID = ID") // does not trigger the observation
                try db.execute(sql: "INSERT INTO T (NAME) VALUES ('Barbara')")
        })
    }
    
    func testRemoveDuplicates() throws {
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion(Table("t").fetchCount)
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
    
    func testRemoveDuplicatesBy() throws {
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
                .removeDuplicates(by: ==),
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
    
    func testRemoveDuplicatesBy2() throws {
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
                .removeDuplicates(by: { _, _ in false }),
            records: [0, 1, 1, 2],
            setup: { db in
                try db.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)")
        },
            recordedUpdates: { db in
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
                try db.execute(sql: "UPDATE T SET ID = ID")
                try db.execute(sql: "INSERT INTO T DEFAULT VALUES")
        })
    }
}
