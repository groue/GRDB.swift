import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: TableRecord, FetchableRecord, Decodable, Equatable {
    var cola1: Int64
    var cola2: String
}
private struct B: TableRecord, FetchableRecord, Decodable, Equatable {
    var colb1: Int64
    var colb2: Int64?
    var colb3: String
}
private struct C: TableRecord, FetchableRecord, Decodable, Equatable {
    var colc1: Int64
    var colc2: Int64
}
private struct D: TableRecord, FetchableRecord, Decodable, Equatable {
    var cold1: Int64
    var cold2: Int64
    var cold3: String
}

class AssociationPrefetchingTests: GRDBTestCase {
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
                    14, nil, "b4",
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
    
    func testIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey()
                        .forKey("bs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colb2" AS "grdb_colb2" \
                        FROM "b" \
                        WHERE ("colb2" IN (1, 2, 3)) \
                        ORDER BY "colb1"
                        """])
                }
                
                // TODO: test fetchCursor
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["bs"])
                    XCTAssertEqual(rows[0].prefetches["bs"]!.count, 2)
                    XCTAssertEqual(rows[0].prefetches["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["bs"])
                    XCTAssertEqual(rows[1].prefetches["bs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colb2": 2]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["bs"])
                    XCTAssertEqual(rows[2].prefetches["bs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["bs"])
                    XCTAssertEqual(row.prefetches["bs"]!.count, 2)
                    XCTAssertEqual(row.prefetches["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var bs: [B]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            bs: [
                                B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            bs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        bs: [
                            B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                        ]))
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .filter(false)
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey())  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM \"a\" WHERE 0 ORDER BY \"cola1\"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 0)
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") == 4)
                        .orderByPrimaryKey()
                        .forKey("bs1"))
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") != 4)
                        .orderByPrimaryKey()
                        .forKey("bs2"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" \
                        WHERE ("cola1" <> 3) \
                        ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colb2" AS "grdb_colb2" \
                        FROM "b" \
                        WHERE (("colb1" = 4) AND ("colb2" IN (1, 2))) \
                        ORDER BY "colb1"
                        """,
                        """
                        SELECT *, "colb2" AS "grdb_colb2" \
                        FROM "b" \
                        WHERE (("colb1" <> 4) AND ("colb2" IN (1, 2))) \
                        ORDER BY "colb1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["bs1", "bs2"])
                    XCTAssertEqual(rows[0].prefetches["bs1"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["bs1"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["bs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["bs2"]![0], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["bs1", "bs2"])
                    XCTAssertEqual(rows[1].prefetches["bs1"]!.count, 0)
                    XCTAssertEqual(rows[1].prefetches["bs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["bs2"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colb2": 2]) // TODO: remove grdb_ column?
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["bs1", "bs2"])
                    XCTAssertEqual(row.prefetches["bs1"]!.count, 1)
                    XCTAssertEqual(row.prefetches["bs1"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["bs2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["bs2"]![0], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var bs1: [B]
                    var bs2: [B]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    print(records)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs1: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            ],
                            bs2: [
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            bs1: [],
                            bs2: [
                                B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        bs1: [
                            B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                        ],
                        bs2: [
                            B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                        ]))
                }
            }
        }
    }
    
    func testIncludingAllHasManyIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey()
                            .forKey("ds"))  // TODO: auto-pluralization
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE ("colc2" IN (1, 2, 3)) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT *, "cold2" AS "grdb_cold2" \
                        FROM "d" \
                        WHERE ("cold2" IN (7, 8, 9)) \
                        ORDER BY "cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].prefetches["ds"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].prefetches["ds"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].prefetches["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].prefetches["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].prefetches["ds"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].prefetches["ds"]![0], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_cold2": 9]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["cs"]![0].prefetches.keys, ["ds"])
                    XCTAssertEqual(row.prefetches["cs"]![0].prefetches["ds"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0].prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds: [D]
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    ds: [
                                        D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    ds: [
                                        D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                ds: [
                                    D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                ]),
                        ]))
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .filter(false)
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE (0 AND ("colc2" IN (1, 2, 3))) \
                        ORDER BY "colc1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 0)
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds: [D]
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: []))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * \
                        FROM "a" \
                        WHERE ("cola1" <> 3) \
                        ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE (("colc1" > 7) AND ("colc2" IN (1, 2))) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT *, "cold2" AS "grdb_cold2" \
                        FROM "d" \
                        WHERE (("cold1" = 11) AND ("cold2" IN (8, 9))) \
                        ORDER BY "cold1"
                        """,
                        """
                        SELECT *, "cold2" AS "grdb_cold2" \
                        FROM "d" \
                        WHERE (("cold1" <> 11) AND ("cold2" IN (8, 9))) \
                        ORDER BY "cold1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE (("colc1" < 9) AND ("colc2" IN (1, 2))) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT *, "cold2" AS "grdb_cold2" \
                        FROM "d" \
                        WHERE (("cold1" = 11) AND ("cold2" IN (7, 8))) \
                        ORDER BY "cold1"
                        """,
                        """
                        SELECT *, "cold2" AS "grdb_cold2" \
                        FROM "d" \
                        WHERE (("cold1" <> 11) AND ("cold2" IN (7, 8))) \
                        ORDER BY "cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].prefetches.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].prefetches["ds1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].prefetches["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0], ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].prefetches.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].prefetches["ds1"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].prefetches["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].prefetches["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1], ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].prefetches.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].prefetches["ds1"]!.count, 0)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].prefetches["ds2"]![0], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_cold2": 9]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0], ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].prefetches.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].prefetches["ds1"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].prefetches["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].prefetches["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8]) // TODO: remove grdb_ column?
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(row.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["cs2"]![0].prefetches.keys, ["ds1", "ds2"])
                    XCTAssertEqual(row.prefetches["cs2"]![0].prefetches["ds1"]!.count, 0)
                    XCTAssertEqual(row.prefetches["cs2"]![0].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs2"]![0].prefetches["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var ds1: [D]
                        var ds2: [D]
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    ds1: [],
                                    ds2: [
                                        D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                    ]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds1: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    ],
                                    ds2: [
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    ds1: [],
                                    ds2: [
                                        D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                                    ]),
                            ],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    ds1: [
                                        D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    ],
                                    ds2: [
                                        D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                    ]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [],
                        cs2: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                ds1: [],
                                ds2: [
                                    D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                ]),
                        ]))
                }
            }
        }
    }
    
    func testIncludingAllHasManyIncludingRequiredOrOptionalHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d".* \
                        FROM "c" \
                        JOIN "d" ON ("d"."cold2" = "c"."colc1") \
                        WHERE ("c"."colc2" IN (1, 2, 3)) \
                        ORDER BY "c"."colc1", "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0].scopes["d"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 3)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0].scopes["d"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs"]![1].scopes["d"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                    XCTAssertEqual(rows[1].prefetches["cs"]![2].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![2].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs"]![2].scopes["d"], ["cold1": 13, "cold2": 9, "cold3": "d4"])
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0].scopes["d"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d: D
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    d: D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                        ]))
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .filter(false)
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey()
                        .forKey("cs"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d".* \
                        FROM "c" \
                        JOIN "d" ON ("d"."cold2" = "c"."colc1") \
                        WHERE (0 AND ("c"."colc2" IN (1, 2, 3))) \
                        ORDER BY "c"."colc1", "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 0)
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d: D
                    }
                    var a: A
                    var cs: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: []),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: []))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("d2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * \
                        FROM "a" \
                        WHERE ("cola1" <> 3) \
                        ORDER BY "cola1"
                        """,
                        """
                        SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d1".*, "d2".* \
                        FROM "c" \
                        LEFT JOIN "d" "d1" ON (("d1"."cold2" = "c"."colc1") AND ("d1"."cold1" = 11)) \
                        JOIN "d" "d2" ON (("d2"."cold2" = "c"."colc1") AND ("d2"."cold1" <> 11)) \
                        WHERE (("c"."colc1" > 7) AND ("c"."colc2" IN (1, 2))) \
                        ORDER BY "c"."colc1", "d1"."cold1", "d2"."cold1"
                        """,
                        """
                        SELECT "c".*, "c"."colc2" AS "grdb_colc2", "d1".*, "d2".* \
                        FROM "c" \
                        LEFT JOIN "d" "d1" ON (("d1"."cold2" = "c"."colc1") AND ("d1"."cold1" = 11)) \
                        JOIN "d" "d2" ON (("d2"."cold2" = "c"."colc1") AND ("d2"."cold1" <> 11)) \
                        WHERE (("c"."colc1" < 9) AND ("c"."colc2" IN (1, 2))) \
                        ORDER BY "c"."colc1", "d1"."cold1", "d2"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0].scopes["d2"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].scopes["d1"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0].scopes["d2"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(rows[1].prefetches["cs1"]![1].scopes["d2"], ["cold1": 13, "cold2": 9, "cold3": "d4"])
                    XCTAssertEqual(rows[1].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].scopes["d1"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0].scopes["d2"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(row.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(row.prefetches["cs2"]![0].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(row.prefetches["cs2"]![0].scopes["d2"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct CInfo: Decodable, Equatable {
                        var c: C
                        var d1: D?
                        var d2: D
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 7, "colc2": 1]),
                                    d1: nil,
                                    d2: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d1: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    d2: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                                Record.CInfo(
                                    c: C(row: ["colc1": 9, "colc2": 2]),
                                    d1: nil,
                                    d2: D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"])),
                            ],
                            cs2: [
                                Record.CInfo(
                                    c: C(row: ["colc1": 8, "colc2": 2]),
                                    d1: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                    d2: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"])),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [],
                        cs2: [
                            Record.CInfo(
                                c: C(row: ["colc1": 7, "colc2": 1]),
                                d1: nil,
                                d2: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"])),
                        ]))
                }
           }
        }
    }
    
    func testIncludingAllHasManyThrough() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3))) \
                        ORDER BY "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[0].prefetches["ds"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetches["ds"]!.count, 3)
                    XCTAssertEqual(rows[1].prefetches["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["ds"])
                    XCTAssertEqual(rows[2].prefetches["ds"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["ds"])
                    XCTAssertEqual(row.prefetches["ds"]!.count, 1)
                    XCTAssertEqual(row.prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var ds: [D]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            ds: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            ds: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            ds: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        ds: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ]))
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).filter(Column("colc1") == 8), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds3"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" \
                        WHERE ("cola1" <> 3) \
                        ORDER BY "cola1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND (("c"."colc1" = 8) AND ("c"."colc2" IN (1, 2)))) \
                        ORDER BY "d"."cold1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2))) \
                        WHERE ("d"."cold1" <> 11) \
                        ORDER BY "d"."cold1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2))) \
                        WHERE ("d"."cold1" = 11) \
                        ORDER BY "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(rows[0].prefetches["ds1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["ds3"]!.count, 0)
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(rows[1].prefetches["ds1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds1"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds2"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds2"]![1], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds3"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["ds3"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(row.prefetches["ds1"]!.count, 0)
                    XCTAssertEqual(row.prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["ds3"]!.count, 0)
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var ds1: [D]
                    var ds2: [D]
                    var ds3: [D]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            ds1: [],
                            ds2: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ],
                            ds3: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            ds1: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                            ],
                            ds2: [
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ],
                            ds3: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        ds1: [],
                        ds2: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ],
                        ds3: []))
                }
            }
        }
    }
    
    func testIncludingAllHasManyThroughIsNotMergedWithHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let cs = A.hasMany(C.self).forKey("cs")
                let request = A
                    .including(all: cs.orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs, using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds"))  // TODO: auto-pluralization
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * FROM "a" ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE ("colc2" IN (1, 2, 3)) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2, 3))) \
                        ORDER BY "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs", "ds"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["ds"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs", "ds"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds"]!.count, 3)
                    XCTAssertEqual(rows[1].prefetches["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[2], ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs", "ds"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 0)
                    XCTAssertEqual(rows[2].prefetches["ds"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs", "ds"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["ds"]!.count, 1)
                    XCTAssertEqual(row.prefetches["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var cs: [C]
                    var ds: [D]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            ds: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs: [
                                C(row: ["colc1": 8, "colc2": 2]),
                                C(row: ["colc1": 9, "colc2": 2]),
                            ],
                            ds: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ]),
                        Record(
                            a: A(row: ["cola1": 3, "cola2": "a3"]),
                            cs: [],
                            ds: []),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        ds: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ]))
                }
            }
            
            // Request with filters
            do {
                let cs1 = A.hasMany(C.self).forKey("cs1")
                let cs2 = A.hasMany(C.self).forKey("cs2")
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: cs1
                        .filter(Column("colc1") != 8)
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs1, using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: cs2
                        .filter(Column("colc1") != 9)
                        .orderByPrimaryKey())
                    .including(all: A
                        .hasMany(D.self, through: cs2, using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT * \
                        FROM "a" \
                        WHERE ("cola1" <> 3) \
                        ORDER BY "cola1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE (("colc1" <> 8) AND ("colc2" IN (1, 2))) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2))) \
                        WHERE ("d"."cold1" <> 11) ORDER BY "d"."cold1"
                        """,
                        """
                        SELECT *, "colc2" AS "grdb_colc2" \
                        FROM "c" \
                        WHERE (("colc1" <> 9) AND ("colc2" IN (1, 2))) \
                        ORDER BY "colc1"
                        """,
                        """
                        SELECT "d".*, "c"."colc2" AS "grdb_colc2" \
                        FROM "d" \
                        JOIN "c" ON (("c"."colc1" = "d"."cold2") AND ("c"."colc2" IN (1, 2))) \
                        WHERE ("d"."cold1" = 11) ORDER BY "d"."cold1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs1", "cs2", "ds1", "ds2"])
                    XCTAssertEqual(rows[0].prefetches["cs1"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs1"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["ds1"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["ds1"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].prefetches["ds2"]!.count, 0)
                    
                    XCTAssertEqual(rows[1], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs1", "cs2", "ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetches["cs1"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs1"]![0], ["colc1": 9, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs2"]![0], ["colc1": 8, "colc2": 2, "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetches["ds1"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds1"]![1], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].prefetches["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["ds2"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2]) // TODO: remove grdb_ column?
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs1", "cs2", "ds1", "ds2"])
                    XCTAssertEqual(row.prefetches["cs1"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs1"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["ds1"]!.count, 1)
                    XCTAssertEqual(row.prefetches["ds1"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.prefetches["ds2"]!.count, 0)
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    var a: A
                    var cs1: [C]
                    var cs2: [C]
                    var ds1: [D]
                    var ds2: [D]
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            cs2: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ],
                            ds1: [
                                D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            ],
                            ds2: []),
                        Record(
                            a: A(row: ["cola1": 2, "cola2": "a2"]),
                            cs1: [
                                C(row: ["colc1": 9, "colc2": 2]),
                            ],
                            cs2: [
                                C(row: ["colc1": 8, "colc2": 2]),
                            ],
                            ds1: [
                                D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                            ],
                            ds2: [
                                D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                            ]),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        a: A(row: ["cola1": 1, "cola2": "a1"]),
                        cs1: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        cs2: [
                            C(row: ["colc1": 7, "colc2": 1]),
                        ],
                        ds1: [
                            D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                        ],
                        ds2: []))
                }
            }
        }
    }

    // TODO: make a variant with joining(optional:)
    func testIncludingOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .including(all: A
                            .hasMany(C.self)
                            .orderByPrimaryKey()
                            .forKey("cs"))  // TODO: auto-pluralization
                    )
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT "b".*, "a".* \
                        FROM "b" \
                        LEFT JOIN "a" ON ("a"."cola1" = "b"."colb2") \
                        ORDER BY "b"."colb1"
                        """,
                        """
                        SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                        FROM "c" \
                        JOIN "a" ON (("a"."cola1" = "c"."colc2") AND ("a"."cola1" IN (1, 2))) \
                        ORDER BY "c"."colc1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 4)
                    
                    XCTAssertEqual(rows[0].unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].scopes.count, 1)
                    XCTAssertEqual(rows[0].scopes["a"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[1].unscoped, ["colb1": 5, "colb2": 1, "colb3": "b2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].scopes.count, 1)
                    XCTAssertEqual(rows[1].scopes["a"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[2].unscoped, ["colb1": 6, "colb2": 2, "colb3": "b3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetches["cs"]!.count, 2)
                    XCTAssertEqual(rows[2].prefetches["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[2].prefetches["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[2].scopes.count, 1)
                    XCTAssertEqual(rows[2].scopes["a"], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetches["cs"]!.count, 2)
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetches["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetches["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[3].unscoped, ["colb1": 14, "colb2": nil, "colb3": "b4"])
                    XCTAssertEqual(rows[3].prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[3].prefetches["cs"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes.count, 1)
                    XCTAssertEqual(rows[3].scopes["a"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a"]!.prefetches.keys, ["cs"])
                    XCTAssertEqual(rows[3].scopes["a"]!.prefetches["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.scopes.count, 1)
                    XCTAssertEqual(row.scopes["a"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.scopes["a"]!.prefetches.keys, ["cs"])
                    XCTAssertEqual(row.scopes["a"]!.prefetches["cs"]!.count, 1)
                    XCTAssertEqual(row.scopes["a"]!.prefetches["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                }
                
                // Record (nested)
                do {
                    // Record.fetchAll
                    struct Record: FetchableRecord, Decodable, Equatable {
                        struct AInfo: Decodable, Equatable {
                            var a: A
                            var cs: [C]
                        }
                        var b: B
                        var a: AInfo?
                    }
                    
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 1, "cola2": "a1"]),
                                    cs: [
                                        C(row: ["colc1": 7, "colc2": 1]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 1, "cola2": "a1"]),
                                    cs: [
                                        C(row: ["colc1": 7, "colc2": 1]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                a: Record.AInfo(
                                    a: A(row: ["cola1": 2, "cola2": "a2"]),
                                    cs: [
                                        C(row: ["colc1": 8, "colc2": 2]),
                                        C(row: ["colc1": 9, "colc2": 2]),
                                    ])),
                            Record(
                                b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                                a: nil),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ])))
                    }
                }
                
                // Record (flat)
                do {
                    // Record.fetchAll
                    struct Record: FetchableRecord, Decodable, Equatable {
                        var b: B
                        var a: A?
                        var cs: [C] // not optional
                    }
                    
                    do {
                        let records = try Record.fetchAll(db, request)
                        XCTAssertEqual(records, [
                            Record(
                                b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                cs: [
                                    C(row: ["colc1": 8, "colc2": 2]),
                                    C(row: ["colc1": 9, "colc2": 2]),
                                ]),
                            Record(
                                b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                                a: nil,
                                cs: []),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        XCTAssertEqual(record, Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ]))
                    }
                }
            }
            
            // Request with filters
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a1")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a1"))
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a2")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .orderByPrimaryKey()
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .orderByPrimaryKey()
                            .forKey("cs2"))
                        .forKey("a2"))
                    .orderByPrimaryKey()
                
                // SQL
                do {
                    sqlQueries.removeAll()
                    _ = try Row.fetchAll(db, request)
                    
                    let selectQueries = sqlQueries.filter { $0.contains("SELECT") }
                    XCTAssertEqual(selectQueries, [
                        """
                        SELECT "b".*, "a1".*, "a2".* \
                        FROM "b" \
                        LEFT JOIN "a" "a1" ON (("a1"."cola1" = "b"."colb2") AND ("a1"."cola2" = 'a1')) \
                        LEFT JOIN "a" "a2" ON (("a2"."cola1" = "b"."colb2") AND ("a2"."cola2" = 'a2')) \
                        ORDER BY "b"."colb1"
                        """,
                        """
                        SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                        FROM "c" \
                        JOIN "a" ON (("a"."cola1" = "c"."colc2") AND (("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)))) \
                        WHERE ("c"."colc1" = 9) \
                        ORDER BY "c"."colc1"
                        """,
                        """
                        SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                        FROM "c" \
                        JOIN "a" ON (("a"."cola1" = "c"."colc2") AND (("a"."cola2" = 'a1') AND ("a"."cola1" IN (1, 2)))) \
                        WHERE ("c"."colc1" <> 9) \
                        ORDER BY "c"."colc1"
                        """,
                        """
                        SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                        FROM "c" \
                        JOIN "a" ON (("a"."cola1" = "c"."colc2") AND (("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)))) \
                        WHERE ("c"."colc1" = 9) \
                        ORDER BY "c"."colc1"
                        """,
                        """
                        SELECT "c".*, "a"."cola1" AS "grdb_cola1" \
                        FROM "c" \
                        JOIN "a" ON (("a"."cola1" = "c"."colc2") AND (("a"."cola2" = 'a2') AND ("a"."cola1" IN (1, 2)))) \
                        WHERE ("c"."colc1" <> 9) \
                        ORDER BY "c"."colc1"
                        """])
                }
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 4)
                    
                    XCTAssertEqual(rows[0].unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(rows[0].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes.count, 2)
                    XCTAssertEqual(rows[0].scopes["a1"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[0].scopes["a2"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetches["cs2"]!.count, 0)
                    
                    XCTAssertEqual(rows[1].unscoped, ["colb1": 5, "colb2": 1, "colb3": "b2"])
                    XCTAssertEqual(rows[1].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes.count, 2)
                    XCTAssertEqual(rows[1].scopes["a1"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[1].scopes["a2"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetches["cs2"]!.count, 0)
                    
                    XCTAssertEqual(rows[2].unscoped, ["colb1": 6, "colb2": 2, "colb3": "b3"])
                    XCTAssertEqual(rows[2].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes.count, 2)
                    XCTAssertEqual(rows[2].scopes["a1"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetches["cs2"]!.count, 0)
                    XCTAssertEqual(rows[2].scopes["a2"], ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetches["cs1"]!.count, 1)
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetches["cs1"]![0], ["colc1": 9, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetches["cs2"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2]) // TODO: remove grdb_ column?
                    
                    XCTAssertEqual(rows[3].unscoped, ["colb1": 14, "colb2": nil, "colb3": "b4"])
                    XCTAssertEqual(rows[3].prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes.count, 2)
                    XCTAssertEqual(rows[3].scopes["a1"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetches["cs2"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a2"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetches["cs2"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(row.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes.count, 2)
                    XCTAssertEqual(row.scopes["a1"], ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.scopes["a1"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes["a1"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(row.scopes["a1"]!.prefetches["cs2"]!.count, 1)
                    XCTAssertEqual(row.scopes["a1"]!.prefetches["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1]) // TODO: remove grdb_ column?
                    XCTAssertEqual(row.scopes["a2"], ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(row.scopes["a2"]!.prefetches.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes["a2"]!.prefetches["cs1"]!.count, 0)
                    XCTAssertEqual(row.scopes["a2"]!.prefetches["cs2"]!.count, 0)
                }
                
                // Record.fetchAll
                struct Record: FetchableRecord, Decodable, Equatable {
                    struct AInfo: Decodable, Equatable {
                        var a: A
                        var cs1: [C]
                        var cs2: [C]
                    }
                    var b: B
                    var a1: AInfo?
                    var a2: AInfo?
                }
                
                do {
                    let records = try Record.fetchAll(db, request)
                    XCTAssertEqual(records, [
                        Record(
                            b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                            a1: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs1: [],
                                cs2: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            a2: nil),
                        Record(
                            b: B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            a1: Record.AInfo(
                                a: A(row: ["cola1": 1, "cola2": "a1"]),
                                cs1: [],
                                cs2: [
                                    C(row: ["colc1": 7, "colc2": 1]),
                                ]),
                            a2: nil),
                        Record(
                            b: B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                            a1: nil,
                            a2: Record.AInfo(
                                a: A(row: ["cola1": 2, "cola2": "a2"]),
                                cs1: [
                                    C(row: ["colc1": 9, "colc2": 2]),
                                ],
                                cs2: [
                                    C(row: ["colc1": 8, "colc2": 2]),
                                ])),
                        Record(
                            b: B(row: ["colb1": 14, "colb2": nil, "colb3": "b4"]),
                            a1: nil,
                            a2: nil),
                        ])
                }
                
                // Record.fetchOne
                do {
                    let record = try Record.fetchOne(db, request)!
                    XCTAssertEqual(record, Record(
                        b: B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                        a1: Record.AInfo(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            cs1: [],
                            cs2: [
                                C(row: ["colc1": 7, "colc2": 1]),
                            ]),
                        a2: nil))
                }
            }
        }
    }
}
