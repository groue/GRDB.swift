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
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.AllRecords<SQLRequest<Player>.RowDecoder>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            let expectedValues = [
                [],
                [Player(id: 1, name: "foo")],
                [Player(id: 1, name: "foo"), Player(id: 2, name: "bar")],
                [Player(id: 2, name: "bar")]]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 1 /* deduplication: don't expect more than expectedValues */)
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
            var observation = SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id").observationForAll()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testTableRecordStaticAll() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.AllRecords<Player>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t WHERE id = 1")                 // -1
            }
            
            let expectedValues = [
                [],
                [Player(id: 1, name: "foo")],
                [Player(id: 1, name: "foo"), Player(id: 2, name: "bar")],
                [Player(id: 2, name: "bar")]]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 1 /* deduplication: don't expect more than expectedValues */)
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
            var observation = Player.observationForAll()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testOne() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.OneRecord<SQLRequest<Player>.RowDecoder>>) throws {
            try writer.write { try $0.execute(sql: "CREATE TABLE t(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)") }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO t (id, name) VALUES (1, 'foo')") // +1
                try db.execute(sql: "UPDATE t SET name = 'foo' WHERE id = 1")     // =
                try db.inTransaction {                                       // +1
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (2, 'bar')")
                    try db.execute(sql: "INSERT INTO t (id, name) VALUES (3, 'baz')")
                    try db.execute(sql: "DELETE FROM t WHERE id = 3")
                    return .commit
                }
                try db.execute(sql: "DELETE FROM t")                              // -1
            }
            
            let expectedValues = [
                nil,
                Player(id: 1, name: "foo"),
                Player(id: 2, name: "bar"),
                nil]
            let values = try wait(
                for: recorder
                    .prefix(expectedValues.count + 1 /* deduplication: don't expect more than expectedValues */)
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
            var observation = SQLRequest<Player>(sql: "SELECT * FROM t ORDER BY id DESC").observationForFirst()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
}
