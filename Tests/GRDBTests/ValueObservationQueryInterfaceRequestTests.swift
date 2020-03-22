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

private struct Parent: TableRecord, FetchableRecord, Decodable, Equatable {
    static let children = hasMany(Child.self)
    var id: Int64
    var name: String
}

private struct Child: TableRecord, FetchableRecord, Decodable, Equatable {
    var id: Int64
    var parentId: Int64
    var name: String
}

private struct ParentInfo: FetchableRecord, Decodable, Equatable {
    var parent: Parent
    var children: [Child]
}

class ValueObservationQueryInterfaceRequestTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId", .integer).references("parent", onDelete: .cascade)
                t.column("name", .text)
            }
            try db.execute(sql: """
                INSERT INTO parent (id, name) VALUES (1, 'foo');
                INSERT INTO parent (id, name) VALUES (2, 'bar');
                INSERT INTO child (id, parentId, name) VALUES (1, 1, 'fooA');
                INSERT INTO child (id, parentId, name) VALUES (2, 1, 'fooB');
                INSERT INTO child (id, parentId, name) VALUES (3, 2, 'barA');
                """)
        }
    }
    
    func testOneRowWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = request.observationForFirst()
        
        let recorder = observation.record(in: dbQueue)
        try dbQueue.inDatabase { db in
            try db.execute(sql: "DELETE FROM child")
        }
        let results = try wait(for: recorder.next(2), timeout: 1)
        
        XCTAssertEqual(results[0]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[0]!.prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        
        XCTAssertEqual(results[1]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[1]!.prefetchedRows["children"], [])
    }
    
    func testAllRowsWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = request.observationForAll()
        
        let recorder = observation.record(in: dbQueue)
        try dbQueue.inDatabase { db in
            try db.execute(sql: "DELETE FROM child")
        }
        let results = try wait(for: recorder.next(2), timeout: 1)
        
        XCTAssertEqual(results[0].count, 2)
        XCTAssertEqual(results[0][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[0][0].prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        XCTAssertEqual(results[0][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[0][1].prefetchedRows["children"], [
            ["id": 3, "parentId": 2, "name": "barA", "grdb_parentId": 2]])
        
        XCTAssertEqual(results[1].count, 2)
        XCTAssertEqual(results[1][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[1][0].prefetchedRows["children"], [])
        XCTAssertEqual(results[1][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[1][1].prefetchedRows["children"], [])
    }

    func testOneRecordWithPrefetchedRows() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.OneRecord<QueryInterfaceRequest<ParentInfo>.RowDecoder>>) throws {
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            let expectedValues = [
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
            ]
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
            let request = Parent
                .including(all: Parent.children.orderByPrimaryKey())
                .orderByPrimaryKey()
                .asRequest(of: ParentInfo.self)
            var observation = request.observationForFirst()
            observation.scheduling = scheduling
            
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
    
    func testAllRecordsWithPrefetchedRows() throws {
        func test(writer: DatabaseWriter, observation: ValueObservation<ValueReducers.AllRecords<QueryInterfaceRequest<ParentInfo>.RowDecoder>>) throws {
            let recorder = observation.record(in: writer)
            try writer.writeWithoutTransaction { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            let expectedValues = [
                [
                    ParentInfo(
                        parent: Parent(id: 1, name: "foo"),
                        children: [
                            Child(id: 1, parentId: 1, name: "fooA"),
                            Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: [
                            Child(id: 3, parentId: 2, name: "barA"),
                    ]),
                ],
                [
                    ParentInfo(
                        parent: Parent(id: 1, name: "foo"),
                        children: []),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: []),
                ],
            ]
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
            let request = Parent
                .including(all: Parent.children.orderByPrimaryKey())
                .orderByPrimaryKey()
                .asRequest(of: ParentInfo.self)
            var observation = request.observationForAll()
            observation.scheduling = scheduling
            
            try test(writer: makeDatabaseQueue(), observation: observation)
            try test(writer: makeDatabasePool(), observation: observation)
        }
    }
}
