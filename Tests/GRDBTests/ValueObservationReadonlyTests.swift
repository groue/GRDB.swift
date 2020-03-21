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

class ValueObservationReadonlyTests: GRDBTestCase {
    
    func testReadOnlyObservation() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<Int>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction {
                try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            let expectedValues = [0, 1]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 2 /* async pool may perform double initial fetch */)
                    .inverted,
                timeout: 0.5)
            try assertValueObservationRecordingMatch(
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
    
    func testWriteObservationFailsByDefaultWithErrorHandling() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<Int>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            let recorder = observation.record(in: writer)
            
            let (values, error) = try wait(for: recorder.failure(), timeout: 0.5)
            XCTAssert(values.isEmpty)
            do {
                throw error
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_READONLY)
                XCTAssertEqual(error.message, "attempt to write a readonly database")
                XCTAssertEqual(error.sql!, "INSERT INTO t DEFAULT VALUES")
                XCTAssertEqual(error.description, "SQLite error 8 with statement `INSERT INTO t DEFAULT VALUES`: attempt to write a readonly database")
            }
        }
        
        let schedulings: [ValueObservationScheduling] = [
            .mainQueue,
            .async(onQueue: .main),
            .unsafe
        ]
        
        for scheduling in schedulings {
            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                return 0
            })
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testWriteObservation() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<Int>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction {
                try $0.execute(sql: "INSERT INTO t DEFAULT VALUES")
            }
            
            let expectedValues = [0, 1]
            let values = try wait(for: recorder.next(2), timeout: 0.5)
            try assertValueObservationRecordingMatch(
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
            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db -> Int in
                XCTAssert(db.isInsideTransaction, "expected a wrapping transaction")
                try db.execute(sql: "CREATE TEMPORARY TABLE temp AS SELECT * FROM t")
                let result = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM temp")!
                try db.execute(sql: "DROP TABLE temp")
                return result
            })
            observation.requiresWriteAccess = true
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testWriteObservationIsWrappedInSavepointWithErrorHandling() throws {
        struct TestError: Error { }
        
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<Void>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT)") }
            let recorder = observation.record(in: writer)
            
            let (_, error) = try wait(for: recorder.failure(), timeout: 0.5)
            do {
                throw error
            } catch is TestError {
                let count = try writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM t")! }
                XCTAssertEqual(count, 0)
            }
        }
        
        let schedulings: [ValueObservationScheduling] = [
            .mainQueue,
            .async(onQueue: .main),
            .unsafe
        ]
        
        for scheduling in schedulings {
            var observation = ValueObservation.tracking(DatabaseRegion.fullDatabase, fetch: { db in
                try db.execute(sql: "INSERT INTO t DEFAULT VALUES")
                throw TestError()
            })
            observation.requiresWriteAccess = true
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
}
