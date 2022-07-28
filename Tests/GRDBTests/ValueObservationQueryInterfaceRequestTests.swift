import XCTest
import GRDB

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
    private func setup(_ db: Database) throws {
        try db.create(table: "parent") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("name", .text)
        }
        try db.create(table: "child") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("parentId", .integer).references("parent", onDelete: .cascade)
            t.column("name", .text)
        }
    }
    
    private func performDatabaseModifications(_ db: Database) throws {
        try db.inTransaction {
            try db.execute(sql: """
                INSERT INTO parent (id, name) VALUES (1, 'foo');
                INSERT INTO parent (id, name) VALUES (2, 'bar');
                """)
            return .commit
        }
        try db.inTransaction {
            try db.execute(sql: """
                INSERT INTO child (id, parentId, name) VALUES (1, 1, 'fooA');
                INSERT INTO child (id, parentId, name) VALUES (2, 1, 'fooB');
                INSERT INTO child (id, parentId, name) VALUES (3, 2, 'barA');
                """)
            return .commit
        }
        try db.inTransaction {
            try db.execute(sql: """
                UPDATE child SET name = 'fooA2' WHERE id = 1;
                """)
            return .commit
        }
        try db.inTransaction {
            try db.execute(sql: """
                INSERT INTO parent (id, name) VALUES (3, 'baz');
                INSERT INTO child (id, parentId, name) VALUES (4, 3, 'bazA');
                """)
            return .commit
        }
        try db.inTransaction {
            try db.execute(sql: """
                DELETE FROM parent WHERE id = 1;
                DELETE FROM child;
                """)
            return .commit
        }
    }
    
    func testOneRowWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write(setup)
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = ValueObservation.trackingConstantRegion(request.fetchOne)
        
        let recorder = observation.record(in: dbQueue)
        try dbQueue.writeWithoutTransaction(performDatabaseModifications)
        let results = try wait(for: recorder.next(6), timeout: 5)
        
        XCTAssertNil(results[0])
        
        XCTAssertEqual(results[1]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[1]!.prefetchedRows["children"], [])
        
        XCTAssertEqual(results[2]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[2]!.prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        
        XCTAssertEqual(results[3]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[3]!.prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA2", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        
        XCTAssertEqual(results[4]!.unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[4]!.prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA2", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        
        XCTAssertEqual(results[5]!.unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[5]!.prefetchedRows["children"], [])
    }
    
    func testAllRowsWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write(setup)
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = ValueObservation.trackingConstantRegion(request.fetchAll)
        
        let recorder = observation.record(in: dbQueue)
        try dbQueue.writeWithoutTransaction(performDatabaseModifications)
        let results = try wait(for: recorder.next(6), timeout: 5)
        
        XCTAssertEqual(results[0].count, 0)
        
        XCTAssertEqual(results[1].count, 2)
        XCTAssertEqual(results[1][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[1][0].prefetchedRows["children"], [])
        XCTAssertEqual(results[1][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[1][1].prefetchedRows["children"], [])
        
        XCTAssertEqual(results[2].count, 2)
        XCTAssertEqual(results[2][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[2][0].prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        XCTAssertEqual(results[2][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[2][1].prefetchedRows["children"], [
            ["id": 3, "parentId": 2, "name": "barA", "grdb_parentId": 2]])
        
        XCTAssertEqual(results[3].count, 2)
        XCTAssertEqual(results[3][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[3][0].prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA2", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        XCTAssertEqual(results[3][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[3][1].prefetchedRows["children"], [
            ["id": 3, "parentId": 2, "name": "barA", "grdb_parentId": 2]])
        
        XCTAssertEqual(results[4].count, 3)
        XCTAssertEqual(results[4][0].unscoped, ["id": 1, "name": "foo"])
        XCTAssertEqual(results[4][0].prefetchedRows["children"], [
            ["id": 1, "parentId": 1, "name": "fooA2", "grdb_parentId": 1],
            ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
        XCTAssertEqual(results[4][1].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[4][1].prefetchedRows["children"], [
            ["id": 3, "parentId": 2, "name": "barA", "grdb_parentId": 2]])
        XCTAssertEqual(results[4][2].unscoped, ["id": 3, "name": "baz"])
        XCTAssertEqual(results[4][2].prefetchedRows["children"], [
            ["id": 4, "parentId": 3, "name": "bazA", "grdb_parentId": 3]])
        
        XCTAssertEqual(results[5].count, 2)
        XCTAssertEqual(results[5][0].unscoped, ["id": 2, "name": "bar"])
        XCTAssertEqual(results[5][0].prefetchedRows["children"], [])
        XCTAssertEqual(results[5][1].unscoped, ["id": 3, "name": "baz"])
        XCTAssertEqual(results[5][1].prefetchedRows["children"], [])
    }
    
    func testOneRecordWithPrefetchedRows() throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchOne),
            records: [
                nil,
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA2"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA2"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 2, name: "bar"),
                    children: []),
            ],
            setup: setup,
            recordedUpdates: performDatabaseModifications)
        
        // The fundamental technique for removing duplicates of non-Equatable types
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { db in try Row.fetchOne(db, request) }
                .removeDuplicates()
                .map { row in try row.map(ParentInfo.init(row:)) },
            records: [
                nil,
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA2"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                ]),
                ParentInfo(
                    parent: Parent(id: 2, name: "bar"),
                    children: []),
            ],
            setup: setup,
            recordedUpdates: performDatabaseModifications)
    }
    
    func testAllRecordsWithPrefetchedRows() throws {
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        
        try assertValueObservation(
            ValueObservation.trackingConstantRegion(request.fetchAll),
            records: [
                [],
                [
                    ParentInfo(
                        parent: Parent(id: 1, name: "foo"),
                        children: []),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: []),
                ],
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
                        children: [
                            Child(id: 1, parentId: 1, name: "fooA2"),
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
                        children: [
                            Child(id: 1, parentId: 1, name: "fooA2"),
                            Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: [
                            Child(id: 3, parentId: 2, name: "barA"),
                    ]),
                    ParentInfo(
                        parent: Parent(id: 3, name: "baz"),
                        children: [
                            Child(id: 4, parentId: 3, name: "bazA"),
                    ]),
                ],
                [
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: []),
                    ParentInfo(
                        parent: Parent(id: 3, name: "baz"),
                        children: []),
                ],
            ],
            setup: setup,
            recordedUpdates: performDatabaseModifications)
        
        // The fundamental technique for removing duplicates of non-Equatable types
        try assertValueObservation(
            ValueObservation
                .trackingConstantRegion { db in try Row.fetchAll(db, request) }
                .removeDuplicates()
                .map { rows in try rows.map(ParentInfo.init(row:)) },
            records: [
                [],
                [
                    ParentInfo(
                        parent: Parent(id: 1, name: "foo"),
                        children: []),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: []),
                ],
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
                        children: [
                            Child(id: 1, parentId: 1, name: "fooA2"),
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
                        children: [
                            Child(id: 1, parentId: 1, name: "fooA2"),
                            Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: [
                            Child(id: 3, parentId: 2, name: "barA"),
                    ]),
                    ParentInfo(
                        parent: Parent(id: 3, name: "baz"),
                        children: [
                            Child(id: 4, parentId: 3, name: "bazA"),
                    ]),
                ],
                [
                    ParentInfo(
                        parent: Parent(id: 2, name: "bar"),
                        children: []),
                    ParentInfo(
                        parent: Parent(id: 3, name: "baz"),
                        children: []),
                ],
            ],
            setup: setup,
            recordedUpdates: performDatabaseModifications)
    }
}
