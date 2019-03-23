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
            var cola1: Int64
            var cola2: String
        }
        struct B: TableRecord, FetchableRecord, Decodable {
            var colb1: Int64
            var colb2: Int64
            var colb3: String
        }
        struct C: TableRecord {
        }
        struct D: TableRecord, FetchableRecord, Decodable {
            var cold1: Int64
            var cold2: Int64
            var cold3: String
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("cola1")
                t.column("cola2", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("colb1")
                t.column("colb2", .integer).references("a")
                t.column("colb3", .text)
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("colc1")
                t.column("colc2", .integer).references("a")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("cold1")
                t.column("cold2", .integer).references("c")
                t.column("cold3", .text)
            }
            try db.execute(
                sql: """
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO a (cola1, cola2) VALUES (?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO b (colb1, colb2, colb3) VALUES (?, ?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
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
                
                sqlQueries.removeAll()
                let infos = try request.fetchAll(db)
                
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT * FROM "a" ORDER BY "cola1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT *, "colb2" AS "grdb_colb2" \
                    FROM "b" \
                    WHERE ("colb2" IN (1, 2, 3)) \
                    ORDER BY "colb1"
                    """))
                
                XCTAssertEqual(infos.count, 3)
                
                XCTAssertEqual(infos[0].a.cola1, 1)
                XCTAssertEqual(infos[0].a.cola2, "a1")
                XCTAssertEqual(infos[0].bs.count, 2)
                XCTAssertEqual(infos[0].bs[0].colb1, 4)
                XCTAssertEqual(infos[0].bs[0].colb2, 1)
                XCTAssertEqual(infos[0].bs[0].colb3, "b1")
                XCTAssertEqual(infos[0].bs[1].colb1, 5)
                XCTAssertEqual(infos[0].bs[1].colb2, 1)
                XCTAssertEqual(infos[0].bs[1].colb3, "b2")
                
                XCTAssertEqual(infos[1].a.cola1, 2)
                XCTAssertEqual(infos[1].a.cola2, "a2")
                XCTAssertEqual(infos[1].bs.count, 1)
                XCTAssertEqual(infos[1].bs[0].colb1, 6)
                XCTAssertEqual(infos[1].bs[0].colb2, 2)
                XCTAssertEqual(infos[1].bs[0].colb3, "b3")
                
                XCTAssertEqual(infos[2].a.cola1, 3)
                XCTAssertEqual(infos[2].a.cola2, "a3")
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
                
                sqlQueries.removeAll()
                let infos = try request.fetchAll(db)
                
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT * FROM "a" ORDER BY "cola1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3))) \
                    ORDER BY "d"."cold1"
                    """))

                XCTAssertEqual(infos.count, 3)
                
                XCTAssertEqual(infos[0].a.cola1, 1)
                XCTAssertEqual(infos[0].a.cola2, "a1")
                XCTAssertEqual(infos[0].ds.count, 1)
                XCTAssertEqual(infos[0].ds[0].cold1, 9)
                XCTAssertEqual(infos[0].ds[0].cold2, 7)
                XCTAssertEqual(infos[0].ds[0].cold3, "d1")
                
                XCTAssertEqual(infos[1].a.cola1, 2)
                XCTAssertEqual(infos[1].a.cola2, "a2")
                XCTAssertEqual(infos[1].ds.count, 2)
                XCTAssertEqual(infos[1].ds[0].cold1, 10)
                XCTAssertEqual(infos[1].ds[0].cold2, 8)
                XCTAssertEqual(infos[1].ds[0].cold3, "d2")
                XCTAssertEqual(infos[1].ds[1].cold1, 11)
                XCTAssertEqual(infos[1].ds[1].cold2, 8)
                XCTAssertEqual(infos[1].ds[1].cold3, "d3")

                XCTAssertEqual(infos[2].a.cola1, 3)
                XCTAssertEqual(infos[2].a.cola2, "a3")
                XCTAssertEqual(infos[2].ds.count, 0)
            }
        }
    }
}
