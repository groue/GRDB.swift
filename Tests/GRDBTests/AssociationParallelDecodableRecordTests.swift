import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> B
// A -> D
private struct A: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "a"
    static let b = belongsTo(B.self)
    static let d = belongsTo(D.self)
    var id: Int64
    var bid: Int64?
    var did: Int64?
    var name: String
}

private struct B: Codable, FetchableRecord, PersistableRecord {
    static let a = hasOne(A.self)
    static let databaseTableName = "b"
    var id: Int64
    var name: String
}

private struct D: Codable, FetchableRecord, PersistableRecord {
    static let a = hasOne(A.self)
    static let databaseTableName = "d"
    var id: Int64
    var name: String
}

private struct AWithRequiredBD: Decodable, FetchableRecord {
    var a: A
    var b: B
    var d: D
    static let b = A.b.forKey(CodingKeys.b)
    static let d = A.d.forKey(CodingKeys.d)
}

private struct AWithOptionalBD: Decodable, FetchableRecord {
    var a: A
    var b: B?
    var d: D?
    static let b = A.b.forKey(CodingKeys.b)
    static let d = A.d.forKey(CodingKeys.d)
}

/// Test support for Decodable records
class AssociationParallelDecodableRecordTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "b") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "d") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "a") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
                t.column("did", .integer).references("d")
                t.column("name", .text)
            }
            
            try B(id: 1, name: "b1").insert(db)
            try B(id: 2, name: "b2").insert(db)
            try B(id: 3, name: "b3").insert(db)
            try D(id: 1, name: "d1").insert(db)
            try A(id: 1, bid: 1, did: 1, name: "a1").insert(db)
            try A(id: 2, bid: 1, did: nil, name: "a2").insert(db)
            try A(id: 3, bid: 2, did: 1, name: "a3").insert(db)
            try A(id: 4, bid: 2, did: nil, name: "a4").insert(db)
            try A(id: 5, bid: nil, did: 1, name: "a5").insert(db)
            try A(id: 6, bid: nil, did: nil, name: "a6").insert(db)
        }
    }
    
    func testParallelTwoIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(required: AWithRequiredBD.b)
            .including(required: AWithRequiredBD.d)
            .order(sql: "a.id, b.id, d.id")
            .asRequest(of: AWithRequiredBD.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        
        XCTAssertEqual(records.count, 2)
        
        XCTAssertEqual(records[0].a.id, 1)
        XCTAssertEqual(records[0].a.bid, 1)
        XCTAssertEqual(records[0].a.did, 1)
        XCTAssertEqual(records[0].a.name, "a1")
        XCTAssertEqual(records[0].b.id, 1)
        XCTAssertEqual(records[0].b.name, "b1")
        XCTAssertEqual(records[0].d.id, 1)
        XCTAssertEqual(records[0].d.name, "d1")
        
        XCTAssertEqual(records[1].a.id, 3)
        XCTAssertEqual(records[1].a.bid, 2)
        XCTAssertEqual(records[1].a.did, 1)
        XCTAssertEqual(records[1].a.name, "a3")
        XCTAssertEqual(records[1].b.id, 2)
        XCTAssertEqual(records[1].b.name, "b2")
        XCTAssertEqual(records[1].d.id, 1)
        XCTAssertEqual(records[1].d.name, "d1")
    }
    
    func testParallelTwoIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(optional: AWithOptionalBD.b)
            .including(optional: AWithOptionalBD.d)
            .order(sql: "a.id, b.id, d.id")
            .asRequest(of: AWithOptionalBD.self)
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }

        XCTAssertEqual(records.count, 6)
        
        XCTAssertEqual(records[0].a.id, 1)
        XCTAssertEqual(records[0].a.bid, 1)
        XCTAssertEqual(records[0].a.did, 1)
        XCTAssertEqual(records[0].a.name, "a1")
        XCTAssertEqual(records[0].b!.id, 1)
        XCTAssertEqual(records[0].b!.name, "b1")
        XCTAssertEqual(records[0].d!.id, 1)
        XCTAssertEqual(records[0].d!.name, "d1")
        
        XCTAssertEqual(records[1].a.id, 2)
        XCTAssertEqual(records[1].a.bid, 1)
        XCTAssertEqual(records[1].a.did, nil)
        XCTAssertEqual(records[1].a.name, "a2")
        XCTAssertEqual(records[1].b!.id, 1)
        XCTAssertEqual(records[1].b!.name, "b1")
        XCTAssertNil(records[1].d)
        
        XCTAssertEqual(records[2].a.id, 3)
        XCTAssertEqual(records[2].a.bid, 2)
        XCTAssertEqual(records[2].a.did, 1)
        XCTAssertEqual(records[2].a.name, "a3")
        XCTAssertEqual(records[2].b!.id, 2)
        XCTAssertEqual(records[2].b!.name, "b2")
        XCTAssertEqual(records[2].d!.id, 1)
        XCTAssertEqual(records[2].d!.name, "d1")
        
        XCTAssertEqual(records[3].a.id, 4)
        XCTAssertEqual(records[3].a.bid, 2)
        XCTAssertEqual(records[3].a.did, nil)
        XCTAssertEqual(records[3].a.name, "a4")
        XCTAssertEqual(records[3].b!.id, 2)
        XCTAssertEqual(records[3].b!.name, "b2")
        XCTAssertNil(records[3].d)
        
        XCTAssertEqual(records[4].a.id, 5)
        XCTAssertEqual(records[4].a.bid, nil)
        XCTAssertEqual(records[4].a.did, 1)
        XCTAssertEqual(records[4].a.name, "a5")
        XCTAssertNil(records[4].b)
        XCTAssertEqual(records[4].d!.id, 1)
        XCTAssertEqual(records[4].d!.name, "d1")
        
        XCTAssertEqual(records[5].a.id, 6)
        XCTAssertEqual(records[5].a.bid, nil)
        XCTAssertEqual(records[5].a.did, nil)
        XCTAssertEqual(records[5].a.name, "a6")
        XCTAssertNil(records[5].b)
        XCTAssertNil(records[5].d)
    }
    
    func testParallelTwoJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .joining(required: A.b)
            .joining(required: A.d)
            .order(sql: "a.id, b.id, d.id")
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        
        XCTAssertEqual(records.count, 2)
        
        XCTAssertEqual(records[0].id, 1)
        XCTAssertEqual(records[0].bid, 1)
        XCTAssertEqual(records[0].did, 1)
        XCTAssertEqual(records[0].name, "a1")
        
        XCTAssertEqual(records[1].id, 3)
        XCTAssertEqual(records[1].bid, 2)
        XCTAssertEqual(records[1].did, 1)
        XCTAssertEqual(records[1].name, "a3")
    }
    
    func testParallelTwoJoiningOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .joining(optional: A.b)
            .joining(optional: A.d)
            .order(sql: "a.id, b.id, d.id")
        let records = try dbQueue.inDatabase { try request.fetchAll($0) }
        
        XCTAssertEqual(records.count, 6)
        
        XCTAssertEqual(records[0].id, 1)
        XCTAssertEqual(records[0].bid, 1)
        XCTAssertEqual(records[0].did, 1)
        XCTAssertEqual(records[0].name, "a1")
        
        XCTAssertEqual(records[1].id, 2)
        XCTAssertEqual(records[1].bid, 1)
        XCTAssertEqual(records[1].did, nil)
        XCTAssertEqual(records[1].name, "a2")
        
        XCTAssertEqual(records[2].id, 3)
        XCTAssertEqual(records[2].bid, 2)
        XCTAssertEqual(records[2].did, 1)
        XCTAssertEqual(records[2].name, "a3")
        
        XCTAssertEqual(records[3].id, 4)
        XCTAssertEqual(records[3].bid, 2)
        XCTAssertEqual(records[3].did, nil)
        XCTAssertEqual(records[3].name, "a4")
        
        XCTAssertEqual(records[4].id, 5)
        XCTAssertEqual(records[4].bid, nil)
        XCTAssertEqual(records[4].did, 1)
        XCTAssertEqual(records[4].name, "a5")
        
        XCTAssertEqual(records[5].id, 6)
        XCTAssertEqual(records[5].bid, nil)
        XCTAssertEqual(records[5].did, nil)
        XCTAssertEqual(records[5].name, "a6")
    }
}

