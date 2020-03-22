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
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.AllRows>) throws {
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
            
            let expectedValues: [[Row]] = [
                [],
                [["id":1, "name":"foo"]],
                [["id":1, "name":"foo"], ["id":2, "name":"bar"]],
                [["id":2, "name":"bar"]]]
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
            var observation = SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id").observationForAll()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testOne() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.OneRow>) throws {
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
            
            let expectedValues: [Row?] = [
                nil,
                ["id":1, "name":"foo"],
                ["id":2, "name":"bar"],
                nil]
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
            var observation = SQLRequest<Row>(sql: "SELECT * FROM t ORDER BY id DESC").observationForFirst()
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testFTS4Observation() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<[Row]>>) throws {
            try writer.write { try $0.create(virtualTable: "ft_documents", using: FTS4()) }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO ft_documents VALUES (?)", arguments: ["foo"])
            }
            
            let expectedValues: [[Row]] = [
                [],
                [["content":"foo"]]]
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
            let request = SQLRequest<Row>(sql: "SELECT * FROM ft_documents")
            var observation = ValueObservation.tracking(value: request.fetchAll)
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testSynchronizedFTS4Observation() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<[Row]>>) throws {
            try writer.write { db in
                try db.create(table: "documents") { t in
                    t.column("id", .integer).primaryKey()
                    t.column("content", .text)
                }
                try db.create(virtualTable: "ft_documents", using: FTS4()) { t in
                    t.synchronize(withTable: "documents")
                    t.column("content")
                }
            }
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "INSERT INTO documents (content) VALUES (?)", arguments: ["foo"])
            }
            
            let expectedValues: [[Row]] = [
                [],
                [["content":"foo"]]]
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
            let request = SQLRequest<Row>(sql: "SELECT * FROM ft_documents")
            var observation = ValueObservation.tracking(value: request.fetchAll)
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testJoinedFTS4Observation() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.Fetch<[Row]>>) throws {
            try writer.write { db in
                try db.create(table: "document") { t in
                    t.autoIncrementedPrimaryKey("id")
                }
                try db.create(virtualTable: "ft_document", using: FTS4()) { t in
                    t.column("content")
                }
            }
            let recorder = observation.record(in: writer)
            try writer.write { db in
                try db.execute(sql: "INSERT INTO document (id) VALUES (?)", arguments: [1])
                try db.execute(sql: "INSERT INTO ft_document (rowid, content) VALUES (?, ?)", arguments: [1, "foo"])
            }
            
            let expectedValues: [[Row]] = [
                [],
                [["id":1]]]
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
            let request = SQLRequest<Row>(sql: """
                SELECT document.* FROM document
                JOIN ft_document ON ft_document.rowid = document.id
                WHERE ft_document MATCH 'foo'
                """)
            var observation = ValueObservation.tracking(value: request.fetchAll)
            observation.scheduling = scheduling
            
            try test(writer: DatabaseQueue(), observation: observation)
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
}
