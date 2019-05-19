import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> B <- C
// A -> D
private struct A: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "a"
    static let defaultB = belongsTo(B.self)
    static let defaultD = belongsTo(D.self)
    static let customB = belongsTo(B.self, key: "customB")
    static let customD = belongsTo(D.self, key: "customD")
    var id: Int64
    var bid: Int64?
    var did: Int64?
    var name: String
}

private struct B: Codable, FetchableRecord, PersistableRecord {
    static let defaultA = hasOne(A.self)
    static let defaultC = hasOne(C.self)
    static let customA = hasOne(A.self, key: "customA")
    static let customC = hasOne(C.self, key: "customC")
    static let databaseTableName = "b"
    var id: Int64
    var name: String
}

private struct C: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "c"
    var id: Int64
    var bid: Int64?
    var name: String
}

private struct D: Codable, FetchableRecord, PersistableRecord {
    static let defaultA = hasOne(A.self)
    static let customA = hasOne(A.self, key: "customA")
    static let databaseTableName = "d"
    var id: Int64
    var name: String
}

/// Test row scopes
class AssociationParallelRowScopesTests: GRDBTestCase {

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
            try db.create(table: "c") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
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
            try C(id: 1, bid: 1, name: "c1").insert(db)
        }
    }
    
    func testDefaultScopeParallelTwoIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB).including(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.including(required: A.defaultB).including(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[3].scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.including(optional: A.defaultB).including(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.including(optional: A.defaultB).including(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[3].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[4].scopes["b"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[4].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["b", "d"])
            XCTAssertEqual(rows[5].scopes["b"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[5].scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.defaultA).including(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.including(required: B.defaultA).including(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(rows[2].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(rows[3].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
        }
        do {
            let request = B.including(optional: B.defaultA).including(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.including(optional: B.defaultA).including(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(rows[2].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(rows[3].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["a", "c"])
            XCTAssertEqual(rows[4].scopes["a"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
            XCTAssertEqual(rows[4].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
        }
    }
    
    func testDefaultScopeParallelTwoIncludingIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB).including(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.defaultB).including(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.defaultB).including(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.defaultB).including(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["b"])
            XCTAssertEqual(rows[4].scopes["b"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["b"])
            XCTAssertEqual(rows[5].scopes["b"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.defaultA).including(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(required: B.defaultA).including(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.defaultA).including(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.defaultA).including(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["a"])
            XCTAssertEqual(rows[4].scopes["a"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }
    
    func testDefaultScopeParallelTwoIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB).joining(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.defaultB).joining(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.defaultB).joining(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.including(optional: A.defaultB).joining(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["b"])
            XCTAssertEqual(rows[4].scopes["b"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["b"])
            XCTAssertEqual(rows[5].scopes["b"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.defaultA).joining(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
        }
        do {
            let request = B.including(required: B.defaultA).joining(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.defaultA).joining(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
        }
        do {
            let request = B.including(optional: B.defaultA).joining(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["a"])
            XCTAssertEqual(rows[4].scopes["a"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }
    
    func testDefaultScopeParallelTwoIncludingJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB).joining(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.defaultB).joining(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.defaultB).joining(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.defaultB).joining(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["b"])
            XCTAssertEqual(rows[4].scopes["b"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["b"])
            XCTAssertEqual(rows[5].scopes["b"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.defaultA).joining(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(required: B.defaultA).joining(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.defaultA).joining(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.defaultA).joining(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["a"])
            XCTAssertEqual(rows[4].scopes["a"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testDefaultScopeParallelTwoJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB).including(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.joining(required: A.defaultB).including(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["d"])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["d"])
            XCTAssertEqual(rows[3].scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.joining(optional: A.defaultB).including(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["d"])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.joining(optional: A.defaultB).including(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["d"])
            XCTAssertEqual(rows[2].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["d"])
            XCTAssertEqual(rows[3].scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["d"])
            XCTAssertEqual(rows[4].scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["d"])
            XCTAssertEqual(rows[5].scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.joining(required: B.defaultA).including(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.joining(required: B.defaultA).including(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["c"])
            XCTAssertEqual(rows[3].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
        }
        do {
            let request = B.joining(optional: B.defaultA).including(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.joining(optional: B.defaultA).including(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["c"])
            XCTAssertEqual(rows[3].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["c"])
            XCTAssertEqual(rows[4].scopes["c"]!, ["id":nil, "bid":nil, "name":nil])
        }
    }

    func testDefaultScopeParallelTwoJoiningIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB).including(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(required: A.defaultB).including(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(optional: A.defaultB).including(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(optional: A.defaultB).including(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["b"])
            XCTAssertEqual(rows[4].scopes["b"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["b"])
            XCTAssertEqual(rows[5].scopes["b"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.joining(required: B.defaultA).including(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(required: B.defaultA).including(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(optional: B.defaultA).including(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(optional: B.defaultA).including(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["a"])
            XCTAssertEqual(rows[0].scopes["a"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["a"])
            XCTAssertEqual(rows[1].scopes["a"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["a"])
            XCTAssertEqual(rows[2].scopes["a"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["a"])
            XCTAssertEqual(rows[3].scopes["a"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["a"])
            XCTAssertEqual(rows[4].scopes["a"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testDefaultScopeParallelTwoJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB).joining(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(required: A.defaultB).joining(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.defaultB).joining(required: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.defaultB).joining(optional: A.defaultD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertTrue(rows[5].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultA).joining(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultA).joining(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.defaultA).joining(required: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.defaultA).joining(optional: B.defaultC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
        }
    }

    func testDefaultScopeParallelTwoJoiningJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB).joining(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(required: A.defaultB).joining(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.defaultB).joining(required: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.defaultB).joining(optional: A.defaultB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertTrue(rows[5].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultA).joining(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultA).joining(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.defaultA).joining(required: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.defaultA).joining(optional: B.defaultA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
        }
    }

    func testCustomScopeParallelTwoIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.customB).including(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.including(required: A.customB).including(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[3].scopes["customD"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.including(optional: A.customB).including(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.including(optional: A.customB).including(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            XCTAssertEqual(rows[3].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[4].scopes["customB"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[4].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customB", "customD"])
            XCTAssertEqual(rows[5].scopes["customB"]!, ["id":nil, "name":nil])
            XCTAssertEqual(rows[5].scopes["customD"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.customA).including(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.including(required: B.customA).including(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(rows[2].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(rows[3].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
        }
        do {
            let request = B.including(optional: B.customA).including(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.including(optional: B.customA).including(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(rows[2].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(rows[3].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customA", "customC"])
            XCTAssertEqual(rows[4].scopes["customA"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
            XCTAssertEqual(rows[4].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
        }
    }
    
    func testCustomScopeParallelTwoIncludingIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.customB).including(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.customB).including(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.customB).including(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.customB).including(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customB"])
            XCTAssertEqual(rows[4].scopes["customB"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customB"])
            XCTAssertEqual(rows[5].scopes["customB"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.customA).including(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(required: B.customA).including(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.customA).including(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.customA).including(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customA"])
            XCTAssertEqual(rows[4].scopes["customA"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testCustomScopeParallelTwoIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.customB).joining(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.customB).joining(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.customB).joining(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.including(optional: A.customB).joining(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customB"])
            XCTAssertEqual(rows[4].scopes["customB"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customB"])
            XCTAssertEqual(rows[5].scopes["customB"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.customA).joining(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
        }
        do {
            let request = B.including(required: B.customA).joining(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.customA).joining(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
        }
        do {
            let request = B.including(optional: B.customA).joining(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customA"])
            XCTAssertEqual(rows[4].scopes["customA"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testCustomScopeParallelTwoIncludingJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.customB).joining(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(required: A.customB).joining(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.customB).joining(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.including(optional: A.customB).joining(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customB"])
            XCTAssertEqual(rows[4].scopes["customB"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customB"])
            XCTAssertEqual(rows[5].scopes["customB"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.customA).joining(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(required: B.customA).joining(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.customA).joining(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.including(optional: B.customA).joining(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customA"])
            XCTAssertEqual(rows[4].scopes["customA"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testCustomScopeParallelTwoJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.customB).including(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customD"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customD"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.joining(required: A.customB).including(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customD"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customD"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customD"])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customD"])
            XCTAssertEqual(rows[3].scopes["customD"]!, ["id":nil, "name":nil])
        }
        do {
            let request = A.joining(optional: A.customB).including(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customD"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customD"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customD"])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = A.joining(optional: A.customB).including(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customD"])
            XCTAssertEqual(rows[0].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customD"])
            XCTAssertEqual(rows[1].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customD"])
            XCTAssertEqual(rows[2].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customD"])
            XCTAssertEqual(rows[3].scopes["customD"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customD"])
            XCTAssertEqual(rows[4].scopes["customD"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customD"])
            XCTAssertEqual(rows[5].scopes["customD"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.joining(required: B.customA).including(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customC"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customC"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.joining(required: B.customA).including(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customC"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customC"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customC"])
            XCTAssertEqual(rows[2].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customC"])
            XCTAssertEqual(rows[3].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
        }
        do {
            let request = B.joining(optional: B.customA).including(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customC"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customC"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
        }
        do {
            let request = B.joining(optional: B.customA).including(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customC"])
            XCTAssertEqual(rows[0].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customC"])
            XCTAssertEqual(rows[1].scopes["customC"]!, ["id":1, "bid":1, "name":"c1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customC"])
            XCTAssertEqual(rows[2].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customC"])
            XCTAssertEqual(rows[3].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customC"])
            XCTAssertEqual(rows[4].scopes["customC"]!, ["id":nil, "bid":nil, "name":nil])
        }
    }

    func testCustomScopeParallelTwoJoiningIncludingSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.customB).including(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(required: A.customB).including(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(optional: A.customB).including(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
        }
        do {
            let request = A.joining(optional: A.customB).including(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customB"])
            XCTAssertEqual(rows[0].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customB"])
            XCTAssertEqual(rows[1].scopes["customB"]!, ["id":1, "name":"b1"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customB"])
            XCTAssertEqual(rows[2].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customB"])
            XCTAssertEqual(rows[3].scopes["customB"]!, ["id":2, "name":"b2"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customB"])
            XCTAssertEqual(rows[4].scopes["customB"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertEqual(Set(rows[5].scopes.names), ["customB"])
            XCTAssertEqual(rows[5].scopes["customB"]!, ["id":nil, "name":nil])
        }
        do {
            let request = B.joining(required: B.customA).including(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(required: B.customA).including(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(optional: B.customA).including(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
        }
        do {
            let request = B.joining(optional: B.customA).including(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["customA"])
            XCTAssertEqual(rows[0].scopes["customA"]!, ["id":1, "bid":1, "did":1, "name":"a1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["customA"])
            XCTAssertEqual(rows[1].scopes["customA"]!, ["id":2, "bid":1, "did":nil, "name":"a2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["customA"])
            XCTAssertEqual(rows[2].scopes["customA"]!, ["id":3, "bid":2, "did":1, "name":"a3"])
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["customA"])
            XCTAssertEqual(rows[3].scopes["customA"]!, ["id":4, "bid":2, "did":nil, "name":"a4"])
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertEqual(Set(rows[4].scopes.names), ["customA"])
            XCTAssertEqual(rows[4].scopes["customA"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
    }

    func testCustomScopeParallelTwoJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.customB).joining(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(required: A.customB).joining(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.customB).joining(required: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.customB).joining(optional: A.customD).order(sql: "a.id, b.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertTrue(rows[5].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.customA).joining(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.customA).joining(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.customA).joining(required: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.customA).joining(optional: B.customC).order(sql: "b.id, a.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
        }
    }

    func testCustomScopeParallelTwoJoiningJoiningSameAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.customB).joining(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(required: A.customB).joining(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.customB).joining(required: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(optional: A.customB).joining(optional: A.customB).order(sql: "a.id, b.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 6)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "did":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":2, "bid":1, "did":nil, "name":"a2"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":3, "bid":2, "did":1, "name":"a3"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":4, "bid":2, "did":nil, "name":"a4"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":5, "bid":nil, "did":1, "name":"a5"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[5].unscoped, ["id":6, "bid":nil, "did":nil, "name":"a6"])
            XCTAssertTrue(rows[5].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.customA).joining(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.customA).joining(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.customA).joining(required: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(optional: B.customA).joining(optional: B.customA).order(sql: "b.id, a.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 5)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[4].unscoped, ["id":3, "name":"b3"])
            XCTAssertTrue(rows[4].scopes.names.isEmpty)
        }
    }
}

