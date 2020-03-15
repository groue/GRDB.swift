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

class ValueObservationCountTests: GRDBTestCase {
    func testCount() throws {
        func test(writer: DatabaseWriter, scheduling: ValueObservationScheduling) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            struct T: TableRecord { }
            var observation = T.all().observationForCount()
            observation.scheduling = scheduling
            let recorder = observation.record(in: writer)
            
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES") // +1
                try db.execute(sql: "UPDATE t SET id = id")         // =
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES") // +1
                try db.inTransaction {                         // +1
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "DELETE FROM t WHERE id = 1")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 2")   // -1
            }
            
            // We don't expect more than five values: [0, 1, 2, 3, 2]
            let expectedValues = [0, 1, 2, 3, 2]
            let values = try wait(for: recorder.prefix(expectedValues.count + 1).inverted, timeout: 0.5)
            let context = "\(type(of: writer)), \(scheduling)"
            XCTAssert(!values.isEmpty, context)
            for count in 1...max(expectedValues.count, values.count) where count <= values.count {
                XCTAssertEqual(
                    expectedValues.suffix(count),
                    values.suffix(count),
                    context)
            }
        }
        let schedulings: [ValueObservationScheduling] = [
            .mainQueue,
            .async(onQueue: .main),
            .unsafe
        ]
        for scheduling in schedulings {
            try test(writer: DatabaseQueue(), scheduling: scheduling)
            try test(writer: makeDatabaseQueue(), scheduling: scheduling)
            try test(writer: makeDatabasePool(), scheduling: scheduling)
        }
    }
    
    func testTableRecordStaticCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
        
        var counts: [Int] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 5
        
        struct T: TableRecord { }
        let observation = T.observationForCount()
        let observer = observation.start(
            in: dbQueue,
            onError: { error in XCTFail("Unexpected error: \(error)") },
            onChange: { count in
                counts.append(count)
                notificationExpectation.fulfill()
        })
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES") // +1
                try db.execute(sql: "UPDATE t SET id = id")         // =
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES") // +1
                try db.inTransaction {                         // +1
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                    try db.execute(sql: "DELETE FROM t WHERE id = 1")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 2")   // -1
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(counts, [0, 1, 2, 3, 2])
        }
    }
}
