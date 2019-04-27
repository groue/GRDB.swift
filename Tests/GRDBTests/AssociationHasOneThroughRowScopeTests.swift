import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: Codable, FetchableRecord, PersistableRecord {
    static let defaultB = belongsTo(B.self)
    static let defaultC = hasOne(C.self, through: defaultB, using: B.c)
    static let customC1 = hasOne(C.self, through: defaultB.forKey("customB"), using: B.c)
    static let customC2 = hasOne(C.self, through: defaultB, using: B.c).forKey("customC2")
    static let customC3 = hasOne(C.self, through: defaultB, using: B.c.forKey("customC3"))
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

/// Test row scopes
class AssociationHasOneThroughRowscopeTests: GRDBTestCase {
    
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
    
    func testJoiningDoesNotUseAnyRowAdapter() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let request = A.joining(required: A.defaultC)
            let (_, adapter) = try request.prepare(db, forSingleResult: false)
            XCTAssertNil(adapter)
        }
    }
    
    func testDefaultScopeIncludingRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.defaultC).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, ["id":1, "name":"c1"])
    }
    
    func testDefaultScopeIncludingOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(optional: A.defaultC).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 3)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, ["id":1, "name":"c1"])
        
        XCTAssertEqual(rows[1].unscoped, ["id":2, "bId":2, "name":"a2"])
        XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
        XCTAssertEqual(rows[1].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!.unscoped, ["id":nil, "name":nil])
        
        XCTAssertEqual(rows[2].unscoped, ["id":3, "bId":nil, "name":"a3"])
        XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
        XCTAssertEqual(rows[2].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[2].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[2].scopes["b"]!.scopes["c"]!.unscoped, ["id":nil, "name":nil])
    }
    
    func testDefaultScopeJoiningRequired() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(required: A.defaultC).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
    
    func testDefaultScopeJoiningOptional() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(optional: A.defaultC).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 3)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)

        XCTAssertEqual(rows[1].unscoped, ["id":2, "bId":2, "name":"a2"])
        XCTAssertTrue(rows[1].scopes.names.isEmpty)

        XCTAssertEqual(rows[2].unscoped, ["id":3, "bId":nil, "name":"a3"])
        XCTAssertTrue(rows[2].scopes.names.isEmpty)
    }
    
    func testCustomC1() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.customC1).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
        XCTAssertEqual(rows[0].scopes["customB"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["customB"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["customB"]!.scopes["c"]!.unscoped, ["id":1, "name":"c1"])
    }
    
    func testCustomC2() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.customC2).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["customC2"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["customC2"]!.unscoped, ["id":1, "name":"c1"])
    }
    
    func testCustomC3() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.customC3).order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["customC3"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["customC3"]!.unscoped, ["id":1, "name":"c1"])
    }
    
    func testDefaultScopeIncludingOptionalIncludingRequiredPivot() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A
            .including(optional: A.defaultC)
            .including(required: A.defaultB)
            .order(sql: "a.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 2)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bId":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "cId":1, "name":"b1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, ["id":1, "name":"c1"])
        
        XCTAssertEqual(rows[1].unscoped, ["id":2, "bId":2, "name":"a2"])
        XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
        XCTAssertEqual(rows[1].scopes["b"]!.unscoped, ["id":2, "cId":nil, "name":"b2"])
        XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!.unscoped, ["id":nil, "name":nil])
    }
}
