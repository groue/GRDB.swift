import XCTest
@testable import GRDB

// a -> b* -> c
//         -> d*
//   -> c*
private struct A: TableRecord, FetchableRecord, Decodable {
    static let databaseTableName = "a"
    static let b = hasOne(B.self)
    static let c = hasOne(C.self)
    var id: Int64
}
private struct B: TableRecord, FetchableRecord, Decodable {
    static let databaseTableName = "b"
    static let c = hasOne(C.self)
    static let d = hasOne(D.self)
    var id: Int64
    var aid: Int64
}
private struct C: TableRecord, FetchableRecord, Decodable {
    static let databaseTableName = "c"
    var id: Int64
    var aid: Int64?
    var bid: Int64?
}
private struct D: TableRecord, FetchableRecord, Decodable {
    static let databaseTableName = "d"
    var id: Int64
    var bid: Int64
}

class AssociationRowScopeSearchTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            // 1. Prepare data
            try db.create(table: "a") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "b") { t in
                t.column("id", .integer).primaryKey()
                t.column("aid", .integer).references("a")
            }
            try db.create(table: "c") { t in
                t.column("id", .integer).primaryKey()
                t.column("aid", .integer).references("a")
                t.column("bid", .integer).references("b")
            }
            try db.create(table: "d") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
            }
            try db.execute(sql: "INSERT INTO a (id) VALUES (1)")
            try db.execute(sql: "INSERT INTO b (id, aid) VALUES (2, 1)")
            try db.execute(sql: "INSERT INTO c (id, aid, bid) VALUES (3, NULL, 2)")
            try db.execute(sql: "INSERT INTO c (id, aid, bid) VALUES (4, 1, NULL)")
            try db.execute(sql: "INSERT INTO d (id, bid) VALUES (5, 2)")
        }
    }
    
    private let testedRequest = A
        .including(required: A.b
            .including(required: B.c)
            .including(required: B.d)
        )
        .including(required: A.c)
    
    func testTestedRequest() throws {
        // Assert that we fetch the expected nested scopes before we start testing breadth-first lookup
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let rows = try testedRequest.asRequest(of: Row.self).fetchAll(db)
            
            XCTAssertEqual(rows.count, 1)
            let row = rows[0]
            
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(row.scopes["b"]!.unscoped, ["id": 2, "aid": 1])
            XCTAssertEqual(row.scopes["b"]!.scopes["c"]!, ["id": 3, "aid": nil, "bid": 2])
            XCTAssertEqual(row.scopes["b"]!.scopes["d"]!, ["id": 5, "bid": 2])
            XCTAssertEqual(row.scopes["c"]!, ["id": 4, "aid": 1, "bid": nil])
        }
    }
            
    func testBreadthFirstScopeLookup() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let row = try testedRequest.asRequest(of: Row.self).fetchOne(db)!
            XCTAssertEqual(row.scopesTree["b"]!.unscoped, ["id": 2, "aid": 1])
            XCTAssertEqual(row.scopesTree["c"]!, ["id": 4, "aid": 1, "bid": nil])
            XCTAssertEqual(row.scopesTree["d"]!, ["id": 5, "bid": 2])
        }
    }
    
    func testFetchableRecordDecoding() throws {
        struct Record: FetchableRecord {
            var a: A
            var b: B
            var c: C
            var d: D
            init(row: Row) throws {
                a = try A(row: row)
                b = try row["b"]
                c = try row["c"]
                d = try row["d"]
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try testedRequest.asRequest(of: Record.self).fetchOne(db)!
            XCTAssertEqual(record.a.id, 1)
            XCTAssertEqual(record.b.id, 2)
            XCTAssertEqual(record.b.aid, 1)
            XCTAssertEqual(record.c.id, 4)
            XCTAssertEqual(record.c.aid, 1)
            XCTAssertNil(record.c.bid)
            XCTAssertEqual(record.d.id, 5)
            XCTAssertEqual(record.d.bid, 2)
        }
    }
    
    func testFlatDecodableRecordDecoding() throws {
        struct Record: FetchableRecord, Decodable {
            var a: A
            var b: B
            var c: C
            var d: D
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try testedRequest.asRequest(of: Record.self).fetchOne(db)!
            XCTAssertEqual(record.a.id, 1)
            XCTAssertEqual(record.b.id, 2)
            XCTAssertEqual(record.b.aid, 1)
            XCTAssertEqual(record.c.id, 4)
            XCTAssertEqual(record.c.aid, 1)
            XCTAssertNil(record.c.bid)
            XCTAssertEqual(record.d.id, 5)
            XCTAssertEqual(record.d.bid, 2)
        }
    }
    
    func testNestedDecodableRecordDecoding() throws {
        struct NestedB: Decodable {
            var b: B
            var c: C
            var d: D
        }
        struct Record: FetchableRecord, Decodable {
            var a: A
            var b: NestedB
            var c: C
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try testedRequest.asRequest(of: Record.self).fetchOne(db)!
            XCTAssertEqual(record.a.id, 1)
            XCTAssertEqual(record.b.b.id, 2)
            XCTAssertEqual(record.b.b.aid, 1)
            XCTAssertEqual(record.b.c.id, 3)
            XCTAssertNil(record.b.c.aid)
            XCTAssertEqual(record.b.c.bid, 2)
            XCTAssertEqual(record.b.d.id, 5)
            XCTAssertEqual(record.b.d.bid, 2)
            XCTAssertEqual(record.c.id, 4)
            XCTAssertEqual(record.c.aid, 1)
            XCTAssertNil(record.c.bid)
        }
    }
    
    func testDecodableWithCustomRowDecoding() throws {
        struct CustomA: FetchableRecord, Decodable {
            var id: Int64
            var custom: Bool?
            init(row: Row) throws {
                id = try row["id"]
                custom = true
            }
        }
        struct CustomB: FetchableRecord, Decodable {
            var id: Int64
            var aid: Int64
            var custom: Bool?
            init(row: Row) throws {
                id = try row["id"]
                aid = try row["aid"]
                custom = true
            }
        }
        struct CustomC: FetchableRecord, Decodable {
            var id: Int64
            var aid: Int64?
            var bid: Int64?
            var custom: Bool?
            init(row: Row) throws {
                id = try row["id"]
                aid = try row["aid"]
                bid = try row["bid"]
                custom = true
            }
        }
        struct CustomD: FetchableRecord, Decodable {
            var id: Int64
            var bid: Int64
            var custom: Bool?
            init(row: Row) throws {
                id = try row["id"]
                bid = try row["bid"]
                custom = true
            }
        }
        struct Record: FetchableRecord, Decodable {
            var a: CustomA
            var b: CustomB
            var c: CustomC
            var d: CustomD
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let record = try testedRequest.asRequest(of: Record.self).fetchOne(db)!
            XCTAssertEqual(record.a.id, 1)
            XCTAssertEqual(record.a.custom, true)
            XCTAssertEqual(record.b.id, 2)
            XCTAssertEqual(record.b.aid, 1)
            XCTAssertEqual(record.b.custom, true)
            XCTAssertEqual(record.c.id, 4)
            XCTAssertEqual(record.c.aid, 1)
            XCTAssertNil(record.c.bid)
            XCTAssertEqual(record.c.custom, true)
            XCTAssertEqual(record.d.id, 5)
            XCTAssertEqual(record.d.bid, 2)
            XCTAssertEqual(record.d.custom, true)
        }
    }
}
