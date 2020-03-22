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
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<Int>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let recorder = observation.record(in: writer)
            
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            let expectedValues = [0, 1, 1, 2]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 2 /* async pool may perform double initial fetch */)
                    .inverted,
                timeout: 0.5)
            assertValueObservationRecordingMatch(
                recorded: values,
                expected: expectedValues,
                "\(type(of: writer)), \(observation.scheduling)")
        }
        
        let schedulings: [ValueObservationScheduling] = [
            .mainQueue,
            .async(onQueue: .main),
            .unsafe
        ]
        
        for scheduling in schedulings {
            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            })
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testRemoveDuplicated() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.RemoveDuplicates<ValueReducers.Fetch<Int>>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            
            let recorder = observation.record(in: writer)
            
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                try db.execute(sql: "UPDATE t SET id = id")
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            let expectedValues = [0, 1, 2]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 1 /* deduplication: don't expect more than expectedValues */)
                    .inverted,
                timeout: 0.5)
            assertValueObservationRecordingMatch(
                recorded: values,
                expected: expectedValues,
                "\(type(of: writer)), \(observation.scheduling)")
        }
        
        let schedulings: [ValueObservationScheduling] = [
            .mainQueue,
            .async(onQueue: .main),
            .unsafe
        ]
        
        for scheduling in schedulings {
            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: {
                try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")!
            }).removeDuplicates()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
}
