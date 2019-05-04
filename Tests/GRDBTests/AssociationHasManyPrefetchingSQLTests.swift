import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: TableRecord, FetchableRecord, Decodable {
    var cola1: Int64
    var cola2: String
}
private struct B: TableRecord, FetchableRecord, Decodable {
    var colb1: Int64
    var colb2: Int64
    var colb3: String
}
private struct C: TableRecord, FetchableRecord, Decodable {
    var colc1: Int64
    var colc2: String
}
private struct D: TableRecord, FetchableRecord, Decodable {
    var cold1: Int64
    var cold2: Int64
    var cold3: String
}

class AssociationHasManyPrefetchingSQLTests: GRDBTestCase {
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
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
                    INSERT INTO c (colc1, colc2) VALUES (?, ?);
                    INSERT INTO d (cold1, cold2, cold3) VALUES (?, ?, ?);
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
                    9, 2,
                    10, 7, "d1",
                    11, 8, "d2",
                    12, 8, "d3",
                    13, 9, "d4",
                    ])
        }
    }
    
    func testHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = A
                .including(all: A
                    .hasMany(B.self)
                    .orderByPrimaryKey()
                    .forKey("bs")) // TODO: auto-pluralization
                .orderByPrimaryKey()
            
            do {
                sqlQueries.removeAll()
                let rows = try Row.fetchAll(db, request)
                
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT * FROM "a" ORDER BY "cola1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT *, "colb2" AS "grdb_colb2" \
                    FROM "b" \
                    WHERE ("colb2" IN (1, 2, 3)) \
                    ORDER BY "colb1"
                    """))

                XCTAssertEqual(rows.count, 3)
                
                XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
//                XCTAssertEqual(rows[0].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["bs"]!.count, 2)
//                XCTAssertEqual(rows[0].prefetchedRows["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[0].prefetchedRows["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]) // TODO: remove grdb_ column
                
                XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
//                XCTAssertEqual(rows[1].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[1].prefetchedRows["bs"]!.count, 1)
//                XCTAssertEqual(rows[1].prefetchedRows["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colb2": 2]) // TODO: remove grdb_ column

                XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
//                XCTAssertEqual(rows[2].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[2].prefetchedRows["bs"]!.count, 0)
            }
            
//            do {
//                struct AInfo: FetchableRecord {
//                    var a: A
//                    var bs: [B]
//
//                    init(row: Row) {
//                        a = A(row: row)
//                        bs = row["bs"]
//                    }
//                }
//                let infos = try request.asRequest(of: AInfo.self).fetchAll(db)
//
//                XCTAssertEqual(infos.count, 3)
//
//                XCTAssertEqual(infos[0].a.cola1, 1)
//                XCTAssertEqual(infos[0].a.cola2, "a1")
//                XCTAssertEqual(infos[0].bs.count, 2)
//                XCTAssertEqual(infos[0].bs[0].colb1, 4)
//                XCTAssertEqual(infos[0].bs[0].colb2, 1)
//                XCTAssertEqual(infos[0].bs[0].colb3, "b1")
//                XCTAssertEqual(infos[0].bs[1].colb1, 5)
//                XCTAssertEqual(infos[0].bs[1].colb2, 1)
//                XCTAssertEqual(infos[0].bs[1].colb3, "b2")
//
//                XCTAssertEqual(infos[1].a.cola1, 2)
//                XCTAssertEqual(infos[1].a.cola2, "a2")
//                XCTAssertEqual(infos[1].bs.count, 1)
//                XCTAssertEqual(infos[1].bs[0].colb1, 6)
//                XCTAssertEqual(infos[1].bs[0].colb2, 2)
//                XCTAssertEqual(infos[1].bs[0].colb3, "b3")
//
//                XCTAssertEqual(infos[2].a.cola1, 3)
//                XCTAssertEqual(infos[2].a.cola2, "a3")
//                XCTAssertEqual(infos[2].bs.count, 0)
//            }
//
//            do {
//                struct AInfo: FetchableRecord, Decodable {
//                    var a: A
//                    var bs: [B]
//                }
//                let infos = try request.asRequest(of: AInfo.self).fetchAll(db)
//
//                XCTAssertEqual(infos.count, 3)
//
//                XCTAssertEqual(infos[0].a.cola1, 1)
//                XCTAssertEqual(infos[0].a.cola2, "a1")
//                XCTAssertEqual(infos[0].bs.count, 2)
//                XCTAssertEqual(infos[0].bs[0].colb1, 4)
//                XCTAssertEqual(infos[0].bs[0].colb2, 1)
//                XCTAssertEqual(infos[0].bs[0].colb3, "b1")
//                XCTAssertEqual(infos[0].bs[1].colb1, 5)
//                XCTAssertEqual(infos[0].bs[1].colb2, 1)
//                XCTAssertEqual(infos[0].bs[1].colb3, "b2")
//
//                XCTAssertEqual(infos[1].a.cola1, 2)
//                XCTAssertEqual(infos[1].a.cola2, "a2")
//                XCTAssertEqual(infos[1].bs.count, 1)
//                XCTAssertEqual(infos[1].bs[0].colb1, 6)
//                XCTAssertEqual(infos[1].bs[0].colb2, 2)
//                XCTAssertEqual(infos[1].bs[0].colb3, "b3")
//
//                XCTAssertEqual(infos[2].a.cola1, 3)
//                XCTAssertEqual(infos[2].a.cola2, "a3")
//                XCTAssertEqual(infos[2].bs.count, 0)
//            }
        }
    }
    
    func testHasManyThrough() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = A
                .including(all: A
                    .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                    .orderByPrimaryKey()
                    .forKey("ds")) // TODO: auto-pluralization
                .orderByPrimaryKey()
            
            do {
                sqlQueries.removeAll()
                let rows = try Row.fetchAll(db, request)
                
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT * FROM "a" ORDER BY "cola1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3))) \
                    ORDER BY "d"."cold1"
                    """))

                XCTAssertEqual(rows.count, 3)
                
                XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
//                XCTAssertEqual(rows[0].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]!.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column
                
                XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
//                XCTAssertEqual(rows[1].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]!.count, 3)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column

                XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
//                XCTAssertEqual(rows[2].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[2].prefetchedRows["ds"]!.count, 0)
            }
            
//            do {
//                struct AInfo: FetchableRecord, Decodable {
//                    var a: A
//                    var ds: [D]
//                }
//                let infos = try request.asRequest(of: AInfo.self).fetchAll(db)
//
//                XCTAssertEqual(infos.count, 3)
//
//                XCTAssertEqual(infos[0].a.cola1, 1)
//                XCTAssertEqual(infos[0].a.cola2, "a1")
//                XCTAssertEqual(infos[0].ds.count, 1)
//                XCTAssertEqual(infos[0].ds[0].cold1, 10)
//                XCTAssertEqual(infos[0].ds[0].cold2, 7)
//                XCTAssertEqual(infos[0].ds[0].cold3, "d1")
//
//                XCTAssertEqual(infos[1].a.cola1, 2)
//                XCTAssertEqual(infos[1].a.cola2, "a2")
//                XCTAssertEqual(infos[1].ds.count, 3)
//                XCTAssertEqual(infos[1].ds[0].cold1, 11)
//                XCTAssertEqual(infos[1].ds[0].cold2, 8)
//                XCTAssertEqual(infos[1].ds[0].cold3, "d2")
//                XCTAssertEqual(infos[1].ds[1].cold1, 12)
//                XCTAssertEqual(infos[1].ds[1].cold2, 8)
//                XCTAssertEqual(infos[1].ds[1].cold3, "d3")
//                XCTAssertEqual(infos[1].ds[2].cold1, 13)
//                XCTAssertEqual(infos[1].ds[2].cold2, 9)
//                XCTAssertEqual(infos[1].ds[2].cold3, "d4")
//
//                XCTAssertEqual(infos[2].a.cola1, 3)
//                XCTAssertEqual(infos[2].a.cola2, "a3")
//                XCTAssertEqual(infos[2].ds.count, 0)
//            }
        }
    }
    
    func testHasManyMergedWithHasManyThrough() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = A
                .including(all: A
                    .hasMany(C.self)
                    .orderByPrimaryKey()
                    .forKey("cs")) // TODO: auto-pluralization
                .including(all: A
                    .hasMany(D.self, through: A.hasMany(C.self).forKey("cs"), using: C.hasMany(D.self))
                    .orderByPrimaryKey()
                    .forKey("ds")) // TODO: auto-pluralization
                .orderByPrimaryKey()
            
            do {
                sqlQueries.removeAll()
                let rows = try Row.fetchAll(db, request)
                
                // TODO
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT * FROM "a" ORDER BY "cola1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT *, "colc2" AS "grdb_colc2" \
                    FROM "c" \
                    WHERE ("colc2" IN (1, 2, 3)) \
                    ORDER BY "colc1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                    FROM "d" \
                    JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3))) \
                    ORDER BY "d"."cold1", "c"."colc1"
                    """))
                print(sqlQueries)
                
                XCTAssertEqual(rows.count, 3)
                
                XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
//                XCTAssertEqual(rows[0].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]!.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column
                
                XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
//                XCTAssertEqual(rows[1].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]!.count, 3)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column
                
                XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
//                XCTAssertEqual(rows[2].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[2].prefetchedRows["ds"]!.count, 0)
            }
            
//            do {
//                struct AInfo: FetchableRecord, Decodable {
//                    var a: A
//                    var ds: [D]
//                }
//                let infos = try request.asRequest(of: AInfo.self).fetchAll(db)
//
//                XCTAssertEqual(infos.count, 3)
//
//                XCTAssertEqual(infos[0].a.cola1, 1)
//                XCTAssertEqual(infos[0].a.cola2, "a1")
//                XCTAssertEqual(infos[0].ds.count, 1)
//                XCTAssertEqual(infos[0].ds[0].cold1, 10)
//                XCTAssertEqual(infos[0].ds[0].cold2, 7)
//                XCTAssertEqual(infos[0].ds[0].cold3, "d1")
//
//                XCTAssertEqual(infos[1].a.cola1, 2)
//                XCTAssertEqual(infos[1].a.cola2, "a2")
//                XCTAssertEqual(infos[1].ds.count, 3)
//                XCTAssertEqual(infos[1].ds[0].cold1, 11)
//                XCTAssertEqual(infos[1].ds[0].cold2, 8)
//                XCTAssertEqual(infos[1].ds[0].cold3, "d2")
//                XCTAssertEqual(infos[1].ds[1].cold1, 12)
//                XCTAssertEqual(infos[1].ds[1].cold2, 8)
//                XCTAssertEqual(infos[1].ds[1].cold3, "d3")
//                XCTAssertEqual(infos[1].ds[2].cold1, 13)
//                XCTAssertEqual(infos[1].ds[2].cold2, 9)
//                XCTAssertEqual(infos[1].ds[2].cold3, "d4")
//
//                XCTAssertEqual(infos[2].a.cola1, 3)
//                XCTAssertEqual(infos[2].a.cola2, "a3")
//                XCTAssertEqual(infos[2].ds.count, 0)
//            }
        }
    }

    func testAssociationIncludingAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            let request = B
                .including(required: B
                    .belongsTo(A.self)
                    .including(all: A
                        .hasMany(C.self)
                        .orderByPrimaryKey()
                        .forKey("cs")) // TODO: auto-pluralization
                )
                .orderByPrimaryKey()

            do {
                sqlQueries.removeAll()
                let rows = try Row.fetchAll(db, request)

                XCTAssertTrue(sqlQueries.contains("""
                    SELECT "b".*, "a".* \
                    FROM "b" \
                    JOIN "a" ON ("a"."cola1" = "b"."colb2") \
                    ORDER BY "b"."colb1"
                    """))
                XCTAssertTrue(sqlQueries.contains("""
                    SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                    FROM "c" \
                    JOIN "a" ON (("a"."cola1" = "c"."colc2") AND ("a"."cola1" IN (1, 2))) \
                    ORDER BY "c"."colc1"
                    """))

//                XCTAssertEqual(rows.count, 3)
//
//                XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
//                XCTAssertEqual(rows[0].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]!.count, 1)
//                XCTAssertEqual(rows[0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column
//
//                XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
//                XCTAssertEqual(rows[1].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]!.count, 3)
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column
//                XCTAssertEqual(rows[1].prefetchedRows["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column
//
//                XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
//                XCTAssertEqual(rows[2].prefetchedRows.count, 1)
//                XCTAssertEqual(rows[2].prefetchedRows["ds"]!.count, 0)
            }

            do {
                struct BInfo: FetchableRecord, Decodable {
                    var b: B
                    var a: A
                    var cs: [C]
                }
            }
        }
    }
}
