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
            var id: Int64
            var name: String
        }
        struct B: TableRecord, FetchableRecord, Decodable {
            var id: Int64
            var aId: Int64
            var name: String
        }
        struct AInfo: FetchableRecord, Decodable {
            var a: A
            var bs: [B]
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
            try db.execute(
                sql: """
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO a (id, name) VALUES (?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    INSERT INTO b (id, aId, name) VALUES (?, ?, ?);
                    """,
                arguments: [
                    1, "a1",
                    2, "a2",
                    3, "a3",
                    1, 1, "b1",
                    2, 1, "b2",
                    3, 2, "b3",
                ])
            
            let request = A
                .including(all: A.bs.orderByPrimaryKey().forKey("bs")) // TODO: auto-pluralization
                .orderByPrimaryKey()
                .asRequest(of: AInfo.self)
            let infos = try request.fetchAll(db)
            
            XCTAssertEqual(infos.count, 3)
            
            XCTAssertEqual(infos[0].a.id, 1)
            XCTAssertEqual(infos[0].a.name, "a1")
            XCTAssertEqual(infos[0].bs.count, 2)
            XCTAssertEqual(infos[0].bs[0].id, 1)
            XCTAssertEqual(infos[0].bs[0].aId, 1)
            XCTAssertEqual(infos[0].bs[0].name, "b1")
            XCTAssertEqual(infos[0].bs[1].id, 2)
            XCTAssertEqual(infos[0].bs[1].aId, 1)
            XCTAssertEqual(infos[0].bs[1].name, "b2")

            XCTAssertEqual(infos[1].a.id, 2)
            XCTAssertEqual(infos[1].a.name, "a2")
            XCTAssertEqual(infos[1].bs.count, 1)
            XCTAssertEqual(infos[1].bs[0].id, 3)
            XCTAssertEqual(infos[1].bs[0].aId, 2)
            XCTAssertEqual(infos[1].bs[0].name, "b3")

            XCTAssertEqual(infos[2].a.id, 3)
            XCTAssertEqual(infos[2].a.name, "a3")
            XCTAssertEqual(infos[2].bs.count, 0)
        }
    }
}
