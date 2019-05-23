import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: Codable, FetchableRecord, PersistableRecord {
    static let b = belongsTo(B.self)
    static let c = hasOne(C.self, through: b, using: B.c)
    var id: Int64
    var bId: Int64?
    var name: String
}

private struct B: Codable, FetchableRecord, PersistableRecord {
    static let c = belongsTo(C.self)
    var id: Int64
    var cId: Int64?
    var name: String
}

private struct C: Codable, FetchableRecord, PersistableRecord {
    var id: Int64
    var name: String
}

private struct AWithRequiredC: Decodable, FetchableRecord {
    var a: A
    var c: C
}

private struct AWithOptionalC: Decodable, FetchableRecord {
    var a: A
    var optionalC: C?
    static let c = A.c.forKey(CodingKeys.optionalC)
}

private struct AWithRequiredBAndOptionalC: Decodable, FetchableRecord {
    var a: A
    var b: B
    var c: C?
}

/// Test support for FetchableRecord records
class AssociationHasOneThroughDecodableRecordTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
                t.column("name", .text)
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
                t.column("name", .text)
            }
            
            try C(id: 1, name: "c1").insert(db)
            try B(id: 1, cId: 1, name: "b1").insert(db)
            try B(id: 2, cId: nil, name: "b2").insert(db)
            try A(id: 1, bId: 1, name: "a1").insert(db)
            try A(id: 2, bId: 2, name: "a2").insert(db)
            try A(id: 3, bId: nil, name: "a3").insert(db)
        }
    }
    
    func testIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(required: A.c)
            .order(sql: "a.id")
            .asRequest(of: AWithRequiredC.self)
        let records = try dbQueue.inDatabase(request.fetchAll)

        XCTAssertEqual(records.count, 1)
        
        XCTAssertEqual(records[0].a.id, 1)
        XCTAssertEqual(records[0].a.bId, 1)
        XCTAssertEqual(records[0].a.name, "a1")
        XCTAssertEqual(records[0].c.id, 1)
        XCTAssertEqual(records[0].c.name, "c1")
    }
    
    func testIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(optional: AWithOptionalC.c)
            .order(sql: "a.id")
            .asRequest(of: AWithOptionalC.self)
        let records = try dbQueue.inDatabase(request.fetchAll)
        
        XCTAssertEqual(records.count, 3)
        
        XCTAssertEqual(records[0].a.id, 1)
        XCTAssertEqual(records[0].a.bId, 1)
        XCTAssertEqual(records[0].a.name, "a1")
        XCTAssertEqual(records[0].optionalC!.id, 1)
        XCTAssertEqual(records[0].optionalC!.name, "c1")

        XCTAssertEqual(records[1].a.id, 2)
        XCTAssertEqual(records[1].a.bId, 2)
        XCTAssertEqual(records[1].a.name, "a2")
        XCTAssertNil(records[1].optionalC)

        XCTAssertEqual(records[2].a.id, 3)
        XCTAssertNil(records[2].a.bId)
        XCTAssertEqual(records[2].a.name, "a3")
        XCTAssertNil(records[2].optionalC)
    }
    
    func testJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .joining(required: A.c)
            .order(sql: "a.id")
        let records = try dbQueue.inDatabase(request.fetchAll)

        XCTAssertEqual(records.count, 1)
        
        XCTAssertEqual(records[0].id, 1)
        XCTAssertEqual(records[0].bId, 1)
        XCTAssertEqual(records[0].name, "a1")
    }
    
    func testJoiningOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .joining(optional: A.c)
            .order(sql: "a.id")
        let records = try dbQueue.inDatabase(request.fetchAll)
        
        XCTAssertEqual(records.count, 3)
        
        XCTAssertEqual(records[0].id, 1)
        XCTAssertEqual(records[0].bId, 1)
        XCTAssertEqual(records[0].name, "a1")
        
        XCTAssertEqual(records[1].id, 2)
        XCTAssertEqual(records[1].bId, 2)
        XCTAssertEqual(records[1].name, "a2")
        
        XCTAssertEqual(records[2].id, 3)
        XCTAssertNil(records[2].bId)
        XCTAssertEqual(records[2].name, "a3")
    }
    
    func testIncludingOptionalIncludingRequiredPivot() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(optional: A.c)
            .including(required: A.b)
            .order(sql: "a.id")
            .asRequest(of: AWithRequiredBAndOptionalC.self)
        let records = try dbQueue.inDatabase(request.fetchAll)
        
        XCTAssertEqual(records.count, 2)
        
        XCTAssertEqual(records[0].a.id, 1)
        XCTAssertEqual(records[0].a.bId, 1)
        XCTAssertEqual(records[0].a.name, "a1")
        XCTAssertEqual(records[0].b.id, 1)
        XCTAssertEqual(records[0].b.name, "b1")
        XCTAssertEqual(records[0].c!.id, 1)
        XCTAssertEqual(records[0].c!.name, "c1")
        
        XCTAssertEqual(records[1].a.id, 2)
        XCTAssertEqual(records[1].a.bId, 2)
        XCTAssertEqual(records[1].a.name, "a2")
        XCTAssertEqual(records[1].b.id, 2)
        XCTAssertEqual(records[1].b.name, "b2")
        XCTAssertNil(records[1].c)
    }
}
