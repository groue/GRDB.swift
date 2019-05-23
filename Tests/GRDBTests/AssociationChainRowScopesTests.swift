import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> B <- C -> D
private struct A: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "a"
    static let defaultB = belongsTo(B.self)
    var id: Int64
    var bid: Int64?
    var name: String
}

private struct B: Codable, FetchableRecord, PersistableRecord {
    static let defaultC = hasOne(C.self)
    static let databaseTableName = "b"
    var id: Int64
    var name: String
}

private struct C: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "c"
    static let defaultD = belongsTo(D.self)
    var id: Int64
    var bid: Int64?
    var did: Int64?
    var name: String
}

private struct D: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "d"
    var id: Int64
    var name: String
}

/// Test row scopes
class AssociationChainRowScopesTests: GRDBTestCase {
    
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
                t.column("name", .text)
            }
            try db.create(table: "c") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
                t.column("did", .integer).references("d")
                t.column("name", .text)
            }
            
            try B(id: 1, name: "b1").insert(db)
            try B(id: 2, name: "b2").insert(db)
            try A(id: 1, bid: 1, name: "a1").insert(db)
            try A(id: 2, bid: 2, name: "a2").insert(db)
            try A(id: 3, bid: nil, name: "a3").insert(db)
            try D(id: 1, name: "d1").insert(db)
            try C(id: 1, bid: 1, did: 1, name: "c1").insert(db)
            try C(id: 2, bid: 1, did: nil, name: "c2").insert(db)
        }
    }
    
    func testChainOfTwoIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB.including(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
        }
        do {
            let request = A.including(required: A.defaultB.including(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }

            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!.unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
        do {
            // TODO: chainOptionalRequired
//            let request = A.including(optional: A.defaultB.including(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = A.including(optional: A.defaultB.including(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }

            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!.unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":3, "bid":nil, "name":"a3"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!.unscoped, ["id":nil, "name":nil])
            XCTAssertEqual(Set(rows[3].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[3].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
        do {
            let request = B.including(required: B.defaultC.including(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }

            XCTAssertEqual(rows.count, 1)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = B.including(required: B.defaultC.including(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }

            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!.unscoped, ["id":2, "bid":1, "did":nil, "name":"c2"])
            XCTAssertEqual(Set(rows[1].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            // TODO: chainOptionalRequired
//            let request = B.including(optional: B.defaultC.including(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = B.including(optional: B.defaultC.including(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }

            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!.unscoped, ["id":2, "bid":1, "did":nil, "name":"c2"])
            XCTAssertEqual(Set(rows[1].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["c"]!.unscoped, ["id":nil, "bid":nil, "did":nil, "name":nil])
            XCTAssertEqual(Set(rows[2].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[2].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
        }
    }
    
    func testChainOfTwoIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.including(required: A.defaultB.joining(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes["b"]!.scopes.names.isEmpty)
        }
        do {
            let request = A.including(required: A.defaultB.joining(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes["b"]!.scopes.names.isEmpty)
        }
        do {
            // TODO: chainOptionalRequired
//            let request = A.including(optional: A.defaultB.joining(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = A.including(optional: A.defaultB.joining(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!, ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!, ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes["b"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[3].unscoped, ["id":3, "bid":nil, "name":"a3"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!, ["id":nil, "name":nil])
            XCTAssertTrue(rows[3].scopes["b"]!.scopes.names.isEmpty)
        }
        do {
            let request = B.including(required: B.defaultC.joining(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 1)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertTrue(rows[0].scopes["c"]!.scopes.names.isEmpty)
        }
        do {
            let request = B.including(required: B.defaultC.joining(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertTrue(rows[0].scopes["c"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            XCTAssertTrue(rows[1].scopes["c"]!.scopes.names.isEmpty)
        }
        do {
            // TODO: chainOptionalRequired
//            let request = B.including(optional: B.defaultC.joining(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = B.including(optional: B.defaultC.joining(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            XCTAssertTrue(rows[0].scopes["c"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            XCTAssertTrue(rows[1].scopes["c"]!.scopes.names.isEmpty)
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
            XCTAssertTrue(rows[2].scopes["c"]!.scopes.names.isEmpty)
        }
    }
    
    func testChainOfTwoJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB.including(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
        }
        do {
            let request = A.joining(required: A.defaultB.including(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[2].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
        do {
            // TODO: chainOptionalRequired
//            let request = A.joining(optional: A.defaultB.including(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = A.joining(optional: A.defaultB.including(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
            XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!, ["id":1, "bid":1, "did":1, "name":"c1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "bid":1, "name":"a1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["b"])
            XCTAssertEqual(rows[1].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[1].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["b"]!.scopes["c"]!, ["id":2, "bid":1, "did":nil, "name":"c2"])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "bid":2, "name":"a2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["b"])
            XCTAssertEqual(rows[2].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[2].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
            
            XCTAssertEqual(rows[3].unscoped, ["id":3, "bid":nil, "name":"a3"])
            XCTAssertEqual(Set(rows[3].scopes.names), ["b"])
            XCTAssertEqual(rows[3].scopes["b"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[3].scopes["b"]!.scopes.names), ["c"])
            XCTAssertEqual(rows[3].scopes["b"]!.scopes["c"]!, ["id":nil, "bid":nil, "did":nil, "name":nil])
        }
        do {
            let request = B.joining(required: B.defaultC.including(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 1)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
        }
        do {
            let request = B.joining(required: B.defaultC.including(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[1].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
        }
        do {
            // TODO: chainOptionalRequired
//            let request = B.joining(optional: B.defaultC.including(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = B.joining(optional: B.defaultC.including(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[0].scopes.names), ["c"])
            XCTAssertEqual(rows[0].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[0].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[0].scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
            
            XCTAssertEqual(rows[1].unscoped, ["id":1, "name":"b1"])
            XCTAssertEqual(Set(rows[1].scopes.names), ["c"])
            XCTAssertEqual(rows[1].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[1].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[1].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
            
            XCTAssertEqual(rows[2].unscoped, ["id":2, "name":"b2"])
            XCTAssertEqual(Set(rows[2].scopes.names), ["c"])
            XCTAssertEqual(rows[2].scopes["c"]!.unscoped, [:])
            XCTAssertEqual(Set(rows[2].scopes["c"]!.scopes.names), ["d"])
            XCTAssertEqual(rows[2].scopes["c"]!.scopes["d"]!, ["id":nil, "name":nil])
        }
    }
    
    func testChainOfTwoJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        do {
            let request = A.joining(required: A.defaultB.joining(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
            
            XCTAssertEqual(rows[1], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            let request = A.joining(required: A.defaultB.joining(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)

            XCTAssertEqual(rows[1], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)

            XCTAssertEqual(rows[2], ["id":2, "bid":2, "name":"a2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
        }
        do {
            // TODO: chainOptionalRequired
//            let request = A.joining(optional: A.defaultB.joining(required: B.defaultC)).order(sql: "a.id, b.id, c.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = A.joining(optional: A.defaultB.joining(optional: B.defaultC)).order(sql: "a.id, b.id, c.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 4)
            
            XCTAssertEqual(rows[0], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)

            XCTAssertEqual(rows[1], ["id":1, "bid":1, "name":"a1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)

            XCTAssertEqual(rows[2], ["id":2, "bid":2, "name":"a2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)

            XCTAssertEqual(rows[3], ["id":3, "bid":nil, "name":"a3"])
            XCTAssertTrue(rows[3].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultC.joining(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 1)
            
            XCTAssertEqual(rows[0], ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)
        }
        do {
            let request = B.joining(required: B.defaultC.joining(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 2)
            
            XCTAssertEqual(rows[0], ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)

            XCTAssertEqual(rows[1], ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)
        }
        do {
            // TODO: chainOptionalRequired
//            let request = B.joining(optional: B.defaultC.joining(required: C.defaultD)).order(sql: "b.id, c.id, d.id")
//            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        }
        do {
            let request = B.joining(optional: B.defaultC.joining(optional: C.defaultD)).order(sql: "b.id, c.id, d.id")
            let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
            
            XCTAssertEqual(rows.count, 3)
            
            XCTAssertEqual(rows[0], ["id":1, "name":"b1"])
            XCTAssertTrue(rows[0].scopes.names.isEmpty)

            XCTAssertEqual(rows[1], ["id":1, "name":"b1"])
            XCTAssertTrue(rows[1].scopes.names.isEmpty)

            XCTAssertEqual(rows[2], ["id":2, "name":"b2"])
            XCTAssertTrue(rows[2].scopes.names.isEmpty)
        }
    }

    func testChainOfThreeIncludingIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.defaultB.including(required: B.defaultC.including(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, ["id":1, "bid":1, "did":1, "name":"c1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes["c"]!.scopes.names), ["d"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
    }
    
    func testChainOfThreeIncludingIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.defaultB.including(required: B.defaultC.joining(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"], ["id":1, "bid":1, "did":1, "name":"c1"])
        XCTAssertTrue(rows[0].scopes["b"]!.scopes["c"]!.scopes.names.isEmpty)
    }

    func testChainOfThreeIncludingJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.defaultB.joining(required: B.defaultC.including(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes["c"]!.scopes.names), ["d"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
    }
    
    func testChainOfThreeIncludingJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.including(required: A.defaultB.joining(required: B.defaultC.joining(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, ["id":1, "name":"b1"])
        XCTAssertTrue(rows[0].scopes["b"]!.scopes.names.isEmpty)
    }
    
    func testChainOfThreeJoiningIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(required: A.defaultB.including(required: B.defaultC.including(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, ["id":1, "bid":1, "did":1, "name":"c1"])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes["c"]!.scopes.names), ["d"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
    }
    
    func testChainOfThreeJoiningIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(required: A.defaultB.including(required: B.defaultC.joining(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"], ["id":1, "bid":1, "did":1, "name":"c1"])
        XCTAssertTrue(rows[0].scopes["b"]!.scopes["c"]!.scopes.names.isEmpty)
    }
    
    func testChainOfThreeJoiningJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(required: A.defaultB.joining(required: B.defaultC.including(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0].unscoped, ["id":1, "bid":1, "name":"a1"])
        XCTAssertEqual(Set(rows[0].scopes.names), ["b"])
        XCTAssertEqual(rows[0].scopes["b"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes.names), ["c"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.unscoped, [:])
        XCTAssertEqual(Set(rows[0].scopes["b"]!.scopes["c"]!.scopes.names), ["d"])
        XCTAssertEqual(rows[0].scopes["b"]!.scopes["c"]!.scopes["d"]!, ["id":1, "name":"d1"])
    }
    
    func testChainOfThreeJoiningJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        let request = A.joining(required: A.defaultB.joining(required: B.defaultC.joining(required: C.defaultD))).order(sql: "a.id, b.id, c.id, d.id")
        let rows = try dbQueue.inDatabase { try Row.fetchAll($0, request) }
        
        XCTAssertEqual(rows.count, 1)
        
        XCTAssertEqual(rows[0], ["id":1, "bid":1, "name":"a1"])
        XCTAssertTrue(rows[0].scopes.names.isEmpty)
    }
}
