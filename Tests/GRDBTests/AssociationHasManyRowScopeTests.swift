import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test row scopes
class AssociationHasManyRowScopeTests: GRDBTestCase {
    func testIndirect() throws {
        struct A: TableRecord, FetchableRecord, Decodable {
            static let bs = hasMany(B.self)
            static let ds = hasMany(D.self, through: hasMany(C.self), using: C.hasMany(D.self))
            var id: Int64
            var name: String
        }
        struct B: TableRecord, FetchableRecord, Decodable {
            var id: Int64
            var aId: Int64
            var name: String
        }
        struct C: TableRecord {
        }
        struct D: TableRecord, FetchableRecord, Decodable {
            var id: Int64
            var cId: Int64
            var name: String
        }
        
        dbConfiguration.trace = { print($0) }
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId", .integer).references("a")
                t.column("name", .text)
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId", .integer).references("a")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId", .integer).references("c")
                t.column("name", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO c (id, aId) VALUES (?, ?);
                    INSERT INTO c (id, aId) VALUES (?, ?);
                    INSERT INTO d (id, cId, name) VALUES (?, ?, ?);
                    INSERT INTO d (id, cId, name) VALUES (?, ?, ?);
                    INSERT INTO d (id, cId, name) VALUES (?, ?, ?);
                    """,
                arguments: [
                    1, "a1",
                    2, "a2",
                    3, "a3",
                    4, 1, "b1",
                    5, 1, "b2",
                    6, 2, "b3",
                    7, 1,
                    8, 2,
                    9, 7, "d1",
                    10, 8, "d2",
                    11, 8, "d3",
                ])
            
            do {
                struct AInfo: FetchableRecord, Decodable {
                    var a: A
                    var bs: [B]
                }
                let request = A
                    .including(all: A.bs.orderByPrimaryKey().forKey("bs")) // TODO: auto-pluralization
                    .orderByPrimaryKey()
                    .asRequest(of: AInfo.self)
                let infos = try request.fetchAll(db)
                
                XCTAssertEqual(infos.count, 3)
                
                XCTAssertEqual(infos[0].a.id, 1)
                XCTAssertEqual(infos[0].a.name, "a1")
                XCTAssertEqual(infos[0].bs.count, 2)
                XCTAssertEqual(infos[0].bs[0].id, 4)
                XCTAssertEqual(infos[0].bs[0].aId, 1)
                XCTAssertEqual(infos[0].bs[0].name, "b1")
                XCTAssertEqual(infos[0].bs[1].id, 5)
                XCTAssertEqual(infos[0].bs[1].aId, 1)
                XCTAssertEqual(infos[0].bs[1].name, "b2")
                
                XCTAssertEqual(infos[1].a.id, 2)
                XCTAssertEqual(infos[1].a.name, "a2")
                XCTAssertEqual(infos[1].bs.count, 1)
                XCTAssertEqual(infos[1].bs[0].id, 6)
                XCTAssertEqual(infos[1].bs[0].aId, 2)
                XCTAssertEqual(infos[1].bs[0].name, "b3")
                
                XCTAssertEqual(infos[2].a.id, 3)
                XCTAssertEqual(infos[2].a.name, "a3")
                XCTAssertEqual(infos[2].bs.count, 0)
            }
            
            do {
                struct AInfo: FetchableRecord, Decodable {
                    var a: A
                    var ds: [D]
                }
                let request = A
                    .including(all: A.ds.orderByPrimaryKey().forKey("ds")) // TODO: auto-pluralization
                    .orderByPrimaryKey()
                    .asRequest(of: AInfo.self)
                let infos = try request.fetchAll(db)
                
                XCTAssertEqual(infos.count, 3)
                
                XCTAssertEqual(infos[0].a.id, 1)
                XCTAssertEqual(infos[0].a.name, "a1")
                XCTAssertEqual(infos[0].ds.count, 1)
                XCTAssertEqual(infos[0].ds[0].id, 9)
                XCTAssertEqual(infos[0].ds[0].cId, 7)
                XCTAssertEqual(infos[0].ds[0].name, "d1")
                
                XCTAssertEqual(infos[1].a.id, 2)
                XCTAssertEqual(infos[1].a.name, "a2")
                XCTAssertEqual(infos[1].ds.count, 2)
                XCTAssertEqual(infos[1].ds[0].id, 10)
                XCTAssertEqual(infos[1].ds[0].cId, 8)
                XCTAssertEqual(infos[1].ds[0].name, "d2")
                XCTAssertEqual(infos[1].ds[1].id, 11)
                XCTAssertEqual(infos[1].ds[1].cId, 8)
                XCTAssertEqual(infos[1].ds[1].name, "d3")

                XCTAssertEqual(infos[2].a.id, 3)
                XCTAssertEqual(infos[2].a.name, "a3")
                XCTAssertEqual(infos[2].ds.count, 0)
            }
        }
    }
}
