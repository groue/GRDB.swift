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
    
    func testOneRowWithPrefetchedRowsDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = ValueObservation.trackingOne(request)
        let observer = try observation.start(in: dbQueue) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.count, 2)
            
            XCTAssertEqual(results[0]!.unscoped, ["id": 1, "name": "foo"])
            XCTAssertEqual(results[0]!.prefetchedRows["children"], [
                ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
                ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
            
            XCTAssertEqual(results[1]!.unscoped, ["id": 1, "name": "foo"])
            XCTAssertEqual(results[1]!.prefetchedRows["children"], [])
        }
    }
    
    func testOneRowWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [Row?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = request.observationForFirst()
        let observer = try observation.start(in: dbQueue) { row in
            results.append(row)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.count, 2)
            
            XCTAssertEqual(results[0]!.unscoped, ["id": 1, "name": "foo"])
            XCTAssertEqual(results[0]!.prefetchedRows["children"], [
                ["id": 1, "parentId": 1, "name": "fooA", "grdb_parentId": 1],
                ["id": 2, "parentId": 1, "name": "fooB", "grdb_parentId": 1]])
            
            XCTAssertEqual(results[1]!.unscoped, ["id": 1, "name": "foo"])
            XCTAssertEqual(results[1]!.prefetchedRows["children"], [])
        }
    }

    func testAllRowsWithPrefetchedRowsDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = ValueObservation.trackingAll(request)
        let observer = try observation.start(in: dbQueue) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.count, 2)
            
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
    }

    func testAllRowsWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [[Row]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: Row.self)
        let observation = request.observationForAll()
        let observer = try observation.start(in: dbQueue) { rows in
            results.append(rows)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results.count, 2)
            
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
    }

    func testOneRecordWithPrefetchedRowsDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()

        var results: [ParentInfo?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2

        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let observation = ValueObservation.trackingOne(request)
        let observer = try observation.start(in: dbQueue) { parentInfo in
            results.append(parentInfo)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }

            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
                ])
        }
    }

    func testOneRecordWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [ParentInfo?] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let observation = request.observationForFirst()
        let observer = try observation.start(in: dbQueue) { parentInfo in
            results.append(parentInfo)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: [
                        Child(id: 1, parentId: 1, name: "fooA"),
                        Child(id: 2, parentId: 1, name: "fooB"),
                    ]),
                ParentInfo(
                    parent: Parent(id: 1, name: "foo"),
                    children: []),
                ])
        }
    }
    
    func testAllRecordsWithPrefetchedRowsDeprecated() throws {
        let dbQueue = try makeDatabaseQueue()
        
        var results: [[ParentInfo]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2
        
        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let observation = ValueObservation.trackingAll(request)
        let observer = try observation.start(in: dbQueue) { parentInfos in
            results.append(parentInfos)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }
            
            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
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
                ])
        }
    }

    func testAllRecordsWithPrefetchedRows() throws {
        let dbQueue = try makeDatabaseQueue()

        var results: [[ParentInfo]] = []
        let notificationExpectation = expectation(description: "notification")
        notificationExpectation.assertForOverFulfill = true
        notificationExpectation.expectedFulfillmentCount = 2

        let request = Parent
            .including(all: Parent.children.orderByPrimaryKey())
            .orderByPrimaryKey()
            .asRequest(of: ParentInfo.self)
        let observation = request.observationForAll()
        let observer = try observation.start(in: dbQueue) { parentInfos in
            results.append(parentInfos)
            notificationExpectation.fulfill()
        }
        try withExtendedLifetime(observer) {
            try dbQueue.inDatabase { db in
                try db.execute(sql: "DELETE FROM child")
            }

            waitForExpectations(timeout: 1, handler: nil)
            XCTAssertEqual(results, [
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
                ])
        }
    }
}
