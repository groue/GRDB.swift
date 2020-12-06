import XCTest
import GRDB

private struct A: TableRecord { }
private struct B: TableRecord { }
private struct C: TableRecord { }
private struct D: TableRecord { }

class AssociationPrefetchingRowTests: GRDBTestCase {
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
                    14, nil, "d5",
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
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + bs: 2 rows
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]!.count, 2)
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[1].prefetchedRows["bs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colb2": 2])
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[2].prefetchedRows["bs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(row.prefetchedRows["bs"]!.count, 2)
                    XCTAssertEqual(row.prefetchedRows["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1])
                    XCTAssertEqual(row.prefetchedRows["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1])
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .none()
                    .including(all: A
                        .hasMany(B.self)
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
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
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + bs1: 1 row
                          + bs2: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["bs1", "bs2"])
                    XCTAssertEqual(rows[0].prefetchedRows["bs1"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["bs1"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["bs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["bs2"]![0], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["bs1", "bs2"])
                    XCTAssertEqual(rows[1].prefetchedRows["bs1"]!.count, 0)
                    XCTAssertEqual(rows[1].prefetchedRows["bs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["bs2"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colb2": 2])
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["bs1", "bs2"])
                    XCTAssertEqual(row.prefetchedRows["bs1"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["bs1"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1])
                    XCTAssertEqual(row.prefetchedRows["bs2"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["bs2"]![0], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1])
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
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].prefetchedRows["ds"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].prefetchedRows["ds"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].prefetchedRows["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].prefetchedRows["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].prefetchedRows["ds"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].prefetchedRows["ds"]![0], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_cold2": 9])
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].prefetchedRows["ds"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7])
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .none()
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs: 0 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 0)
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
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs1: 0 row
                          + cs2: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].prefetchedRows.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].prefetchedRows["ds1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].prefetchedRows["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].prefetchedRows.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].prefetchedRows["ds1"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].prefetchedRows["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].prefetchedRows["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].prefetchedRows.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].prefetchedRows["ds1"]!.count, 0)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].prefetchedRows["ds2"]![0], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_cold2": 9])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].prefetchedRows.keys, ["ds1", "ds2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].prefetchedRows["ds1"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].prefetchedRows["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_cold2": 8])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].prefetchedRows["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_cold2": 8])
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(row.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].prefetchedRows.keys, ["ds1", "ds2"])
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].prefetchedRows["ds1"]!.count, 0)
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].prefetchedRows["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_cold2": 7])
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
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0].scopes["d"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 3)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0].scopes["d"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![1].scopes["d"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![2].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![2].scopes.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![2].scopes["d"], ["cold1": 13, "cold2": 9, "cold3": "d4"])
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].scopes.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0].scopes["d"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                }
            }
            
            // Request with avoided prefetch
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .none()
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs: 0 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 0)
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 0)
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
                            .forKey("ds1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .orderByPrimaryKey()
                            .forKey("ds1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .orderByPrimaryKey()
                            .forKey("ds2"))
                        .orderByPrimaryKey()
                        .forKey("cs2"))
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + cs1: 0 row
                          + cs2: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(rows[0].prefetchedRows["cs2"]![0].scopes["d2"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].scopes["d1"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![0].scopes["d2"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].unscoped, ["colc1": 9, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(rows[1].prefetchedRows["cs1"]![1].scopes["d2"], ["cold1": 13, "cold2": 9, "cold3": "d4"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].unscoped, ["colc1": 8, "colc2": 2, "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].scopes["d1"], ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs2"]![0].scopes["d2"], ["cold1": 12, "cold2": 8, "cold3": "d3"])
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(row.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].unscoped, ["colc1": 7, "colc2": 1, "grdb_colc2": 1])
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].scopes.count, 2)
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].scopes["d1"], ["cold1": nil, "cold2": nil, "cold3": nil])
                    XCTAssertEqual(row.prefetchedRows["cs2"]![0].scopes["d2"], ["cold1": 10, "cold2": 7, "cold3": "d1"])
                }
            }
        }
    }
    
    func testIncludingAllHasManyThroughHasManyUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 3)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + ds: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[0].prefetchedRows["ds"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1])
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[1].prefetchedRows["ds"]!.count, 3)
                    XCTAssertEqual(rows[1].prefetchedRows["ds"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds"]![2], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2])
                    
                    XCTAssertEqual(rows[2].unscoped, ["cola1": 3, "cola2": "a3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(rows[2].prefetchedRows["ds"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["ds"])
                    XCTAssertEqual(row.prefetchedRows["ds"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["ds"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1])
                }
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).filter(Column("colc1") == 8).forKey("cs1"), using: C.hasMany(D.self))
                        .orderByPrimaryKey()
                        .forKey("ds1"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .orderByPrimaryKey()
                        .forKey("ds2"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .orderByPrimaryKey()
                        .forKey("ds3"))
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 2)
                    
                    XCTAssertEqual(rows[0].description, "[cola1:1 cola2:\"a1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cola1:1 cola2:"a1"]
                          + ds1: 0 row
                          + ds2: 1 row
                          + ds3: 0 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(rows[0].prefetchedRows["ds1"]!.count, 0)
                    XCTAssertEqual(rows[0].prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1])
                    XCTAssertEqual(rows[0].prefetchedRows["ds3"]!.count, 0)
                    
                    XCTAssertEqual(rows[1].unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(rows[1].prefetchedRows["ds1"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["ds1"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds1"]![1], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds2"]!.count, 2)
                    XCTAssertEqual(rows[1].prefetchedRows["ds2"]![0], ["cold1": 12, "cold2": 8, "cold3": "d3", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds2"]![1], ["cold1": 13, "cold2": 9, "cold3": "d4", "grdb_colc2": 2])
                    XCTAssertEqual(rows[1].prefetchedRows["ds3"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["ds3"]![0], ["cold1": 11, "cold2": 8, "cold3": "d2", "grdb_colc2": 2])
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["ds1", "ds2", "ds3"])
                    XCTAssertEqual(row.prefetchedRows["ds1"]!.count, 0)
                    XCTAssertEqual(row.prefetchedRows["ds2"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["ds2"]![0], ["cold1": 10, "cold2": 7, "cold3": "d1", "grdb_colc2": 1])
                    XCTAssertEqual(row.prefetchedRows["ds3"]!.count, 0)
                }
            }
        }
    }
    
    func testIncludingAllHasManyThroughBelongsToUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = B
                    .including(all: B
                        .hasMany(C.self, through: B.belongsTo(A.self), using: A.hasMany(C.self))
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 4)
                    
                    XCTAssertEqual(rows[0].description, "[colb1:4 colb2:1 colb3:\"b1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [colb1:4 colb2:1 colb3:"b1"]
                          + cs: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssert(rows[0].scopes.isEmpty)
                    
                    XCTAssertEqual(rows[1].unscoped, ["colb1": 5, "colb2": 1, "colb3": "b2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssert(rows[1].scopes.isEmpty)

                    XCTAssertEqual(rows[2].unscoped, ["colb1": 6, "colb2": 2, "colb3": "b3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 2)
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_cola1": 2])
                    XCTAssert(rows[2].scopes.isEmpty)

                    XCTAssertEqual(rows[3].unscoped, ["colb1": 14, "colb2": nil, "colb3": "b4"])
                    XCTAssertEqual(rows[3].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[3].prefetchedRows["cs"]!.count, 0)
                    XCTAssert(rows[3].scopes.isEmpty)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssert(row.scopes.isEmpty)
                }
            }
        }
    }
    
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
                            .orderByPrimaryKey())
                    )
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 4)
                    
                    XCTAssertEqual(rows[0].description, "[colb1:4 colb2:1 colb3:\"b1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [colb1:4 colb2:1 colb3:"b1"]
                          unadapted: [colb1:4 colb2:1 colb3:"b1" cola1:1 cola2:"a1"]
                          - a: [cola1:1 cola2:"a1"]
                            + cs: 1 row
                          + cs: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(rows[0].scopes.count, 1)
                    XCTAssertEqual(rows[0].scopes["a"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[0].scopes["a"]!.prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    
                    XCTAssertEqual(rows[1].unscoped, ["colb1": 5, "colb2": 1, "colb3": "b2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(rows[1].scopes.count, 1)
                    XCTAssertEqual(rows[1].scopes["a"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(rows[1].scopes["a"]!.prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    
                    XCTAssertEqual(rows[2].unscoped, ["colb1": 6, "colb2": 2, "colb3": "b3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]!.count, 2)
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2])
                    XCTAssertEqual(rows[2].prefetchedRows["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_cola1": 2])
                    XCTAssertEqual(rows[2].scopes.count, 1)
                    XCTAssertEqual(rows[2].scopes["a"]!.unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetchedRows["cs"]!.count, 2)
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetchedRows["cs"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2])
                    XCTAssertEqual(rows[2].scopes["a"]!.prefetchedRows["cs"]![1], ["colc1": 9, "colc2": 2, "grdb_cola1": 2])
                    
                    XCTAssertEqual(rows[3].unscoped, ["colb1": 14, "colb2": nil, "colb3": "b4"])
                    XCTAssertEqual(rows[3].prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[3].prefetchedRows["cs"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes.count, 1)
                    XCTAssertEqual(rows[3].scopes["a"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a"]!.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(rows[3].scopes["a"]!.prefetchedRows["cs"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(row.prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(row.scopes.count, 1)
                    XCTAssertEqual(row.scopes["a"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.scopes["a"]!.prefetchedRows.keys, ["cs"])
                    XCTAssertEqual(row.scopes["a"]!.prefetchedRows["cs"]!.count, 1)
                    XCTAssertEqual(row.scopes["a"]!.prefetchedRows["cs"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
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
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 4)
                    
                    XCTAssertEqual(rows[0].description, "[colb1:4 colb2:1 colb3:\"b1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [colb1:4 colb2:1 colb3:"b1"]
                          unadapted: [colb1:4 colb2:1 colb3:"b1" cola1:1 cola2:"a1" cola1:NULL cola2:NULL]
                          - a1: [cola1:1 cola2:"a1"]
                            + cs1: 0 row
                            + cs2: 1 row
                          - a2: [cola1:NULL cola2:NULL]
                            + cs1: 0 row
                            + cs2: 0 row
                          + cs1: 0 row
                          + cs2: 1 row
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes.count, 2)
                    XCTAssertEqual(rows[0].scopes["a1"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[0].scopes["a1"]!.prefetchedRows["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(rows[0].scopes["a2"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[0].scopes["a2"]!.prefetchedRows["cs2"]!.count, 0)
                    
                    XCTAssertEqual(rows[1].unscoped, ["colb1": 5, "colb2": 1, "colb3": "b2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes.count, 2)
                    XCTAssertEqual(rows[1].scopes["a1"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[1].scopes["a1"]!.prefetchedRows["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(rows[1].scopes["a2"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[1].scopes["a2"]!.prefetchedRows["cs2"]!.count, 0)
                    
                    XCTAssertEqual(rows[2].unscoped, ["colb1": 6, "colb2": 2, "colb3": "b3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes.count, 2)
                    XCTAssertEqual(rows[2].scopes["a1"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[2].scopes["a1"]!.prefetchedRows["cs2"]!.count, 0)
                    XCTAssertEqual(rows[2].scopes["a2"]!.unscoped, ["cola1": 2, "cola2": "a2"])
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetchedRows["cs1"]!.count, 1)
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetchedRows["cs1"]![0], ["colc1": 9, "colc2": 2, "grdb_cola1": 2])
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(rows[2].scopes["a2"]!.prefetchedRows["cs2"]![0], ["colc1": 8, "colc2": 2, "grdb_cola1": 2])
                    
                    XCTAssertEqual(rows[3].unscoped, ["colb1": 14, "colb2": nil, "colb3": "b4"])
                    XCTAssertEqual(rows[3].prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes.count, 2)
                    XCTAssertEqual(rows[3].scopes["a1"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a1"]!.prefetchedRows["cs2"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a2"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(rows[3].scopes["a2"]!.prefetchedRows["cs2"]!.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["colb1": 4, "colb2": 1, "colb3": "b1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes.count, 2)
                    XCTAssertEqual(row.scopes["a1"]!.unscoped, ["cola1": 1, "cola2": "a1"])
                    XCTAssertEqual(row.scopes["a1"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes["a1"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(row.scopes["a1"]!.prefetchedRows["cs2"]!.count, 1)
                    XCTAssertEqual(row.scopes["a1"]!.prefetchedRows["cs2"]![0], ["colc1": 7, "colc2": 1, "grdb_cola1": 1])
                    XCTAssertEqual(row.scopes["a2"]!.unscoped, ["cola1": nil, "cola2": nil])
                    XCTAssertEqual(row.scopes["a2"]!.prefetchedRows.keys, ["cs1", "cs2"])
                    XCTAssertEqual(row.scopes["a2"]!.prefetchedRows["cs1"]!.count, 0)
                    XCTAssertEqual(row.scopes["a2"]!.prefetchedRows["cs2"]!.count, 0)
                }
            }
        }
    }
    
    func testJoiningOptionalHasOneThroughIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .joining(optional: D
                        .hasOne(A.self, through: D.belongsTo(C.self), using: C.belongsTo(A.self))
                        .including(all: A
                            .hasMany(B.self)
                            .orderByPrimaryKey()))
                    .orderByPrimaryKey()
                
                // Row.fetchAll
                do {
                    let rows = try Row.fetchAll(db, request)
                    XCTAssertEqual(rows.count, 5)
                    
                    XCTAssertEqual(rows[0].description, "[cold1:10 cold2:7 cold3:\"d1\"]")
                    XCTAssertEqual(rows[0].debugDescription, """
                        ▿ [cold1:10 cold2:7 cold3:"d1"]
                          + bs: 2 rows
                        """)
                    
                    XCTAssertEqual(rows[0].unscoped, ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    XCTAssertEqual(rows[0].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]!.count, 2)
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colc1": 7])
                    XCTAssertEqual(rows[0].prefetchedRows["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colc1": 7])
                    XCTAssertEqual(rows[0].scopes.count, 0)

                    XCTAssertEqual(rows[1].unscoped, ["cold1": 11, "cold2": 8, "cold3": "d2"])
                    XCTAssertEqual(rows[1].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[1].prefetchedRows["bs"]!.count, 1)
                    XCTAssertEqual(rows[1].prefetchedRows["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colc1": 8])
                    XCTAssertEqual(rows[1].scopes.count, 0)

                    XCTAssertEqual(rows[2].unscoped, ["cold1": 12, "cold2": 8, "cold3": "d3"])
                    XCTAssertEqual(rows[2].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[2].prefetchedRows["bs"]!.count, 1)
                    XCTAssertEqual(rows[2].prefetchedRows["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colc1": 8])
                    XCTAssertEqual(rows[2].scopes.count, 0)

                    XCTAssertEqual(rows[3].unscoped, ["cold1": 13, "cold2": 9, "cold3": "d4"])
                    XCTAssertEqual(rows[3].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[3].prefetchedRows["bs"]!.count, 1)
                    XCTAssertEqual(rows[3].prefetchedRows["bs"]![0], ["colb1": 6, "colb2": 2, "colb3": "b3", "grdb_colc1": 9])
                    XCTAssertEqual(rows[3].scopes.count, 0)

                    XCTAssertEqual(rows[4].unscoped, ["cold1": 14, "cold2": nil, "cold3": "d5"])
                    XCTAssertEqual(rows[4].prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(rows[4].prefetchedRows["bs"]!.count, 0)
                    XCTAssertEqual(rows[4].scopes.count, 0)
                }
                
                // Row.fetchOne
                do {
                    let row = try Row.fetchOne(db, request)!
                    
                    XCTAssertEqual(row.unscoped, ["cold1": 10, "cold2": 7, "cold3": "d1"])
                    XCTAssertEqual(row.prefetchedRows.keys, ["bs"])
                    XCTAssertEqual(row.prefetchedRows["bs"]!.count, 2)
                    XCTAssertEqual(row.prefetchedRows["bs"]![0], ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colc1": 7])
                    XCTAssertEqual(row.prefetchedRows["bs"]![1], ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colc1": 7])
                    XCTAssertEqual(row.scopes.count, 0)
                }
            }
        }
    }

    func testEquatable() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request1 = A
                .orderByPrimaryKey()
            let request2 = A
                .including(all: A.hasMany(B.self).orderByPrimaryKey())
                .orderByPrimaryKey()
            let request3 = A
                .including(all: A.hasMany(B.self).none())
                .orderByPrimaryKey()
            
            let row1 = try Row.fetchOne(db, request1)!
            let row2 = try Row.fetchOne(db, request2)!
            let row3 = try Row.fetchOne(db, request3)!
            
            XCTAssertEqual(row1.unscoped, ["cola1": 1, "cola2": "a1"])
            XCTAssertEqual(row2.unscoped, ["cola1": 1, "cola2": "a1"])
            XCTAssertEqual(row3.unscoped, ["cola1": 1, "cola2": "a1"])
            
            XCTAssertTrue(row1.prefetchedRows.isEmpty)
            XCTAssertFalse(row2.prefetchedRows.isEmpty)
            XCTAssertFalse(row3.prefetchedRows.isEmpty)
            
            XCTAssertNil(row1.prefetchedRows["bs"])
            XCTAssertEqual(row2.prefetchedRows["bs"], [
                ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1],
                ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]])
            XCTAssertEqual(row3.prefetchedRows["bs"], [])
            
            XCTAssertEqual(row1, row1)
            XCTAssertEqual(row1, row1.copy())
            XCTAssertEqual(row1, row1.unscoped)
            XCTAssertEqual(row1, row2.unscoped)
            XCTAssertEqual(row1, row3.unscoped)
            XCTAssertNotEqual(row1, row2)
            XCTAssertNotEqual(row1, row3)

            XCTAssertEqual(row2, row2)
            XCTAssertEqual(row2, row2.copy())
            XCTAssertNotEqual(row2, row2.unscoped)
            XCTAssertNotEqual(row2, row3)

            XCTAssertEqual(row3, row3)
            XCTAssertEqual(row3, row3.copy())
            XCTAssertNotEqual(row3, row3.unscoped)
        }
    }
    
    func testCopy() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            let request1 = A
                .orderByPrimaryKey()
            let request2 = A
                .including(all: A.hasMany(B.self).orderByPrimaryKey())
                .orderByPrimaryKey()
            let request3 = A
                .including(all: A.hasMany(B.self).none())
                .orderByPrimaryKey()
            
            let row1 = try Row.fetchOne(db, request1)!.copy()
            let row2 = try Row.fetchOne(db, request2)!.copy()
            let row3 = try Row.fetchOne(db, request3)!.copy()
            
            XCTAssertEqual(row1.unscoped, ["cola1": 1, "cola2": "a1"])
            XCTAssertEqual(row2.unscoped, ["cola1": 1, "cola2": "a1"])
            XCTAssertEqual(row3.unscoped, ["cola1": 1, "cola2": "a1"])
            
            XCTAssertTrue(row1.prefetchedRows.isEmpty)
            XCTAssertFalse(row2.prefetchedRows.isEmpty)
            XCTAssertFalse(row3.prefetchedRows.isEmpty)
            
            XCTAssertNil(row1.prefetchedRows["bs"])
            XCTAssertEqual(row2.prefetchedRows["bs"], [
                ["colb1": 4, "colb2": 1, "colb3": "b1", "grdb_colb2": 1],
                ["colb1": 5, "colb2": 1, "colb3": "b2", "grdb_colb2": 1]])
            XCTAssertEqual(row3.prefetchedRows["bs"], [])
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/871
    func testCompoundColumnLimit() throws {
        struct Parent: Encodable, PersistableRecord {
            let a: Int
            let b: Int
            static let children = hasMany(Child.self)
        }

        struct Child: Encodable, PersistableRecord {
            let a: Int
            let b: Int
        }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .integer).notNull()
                t.column("b", .integer).notNull()
                t.primaryKey(["a", "b"])
            }
            
            try db.create(table: "child") { t in
                t.column("a", .integer).notNull()
                t.column("b", .integer).notNull()
                t.foreignKey(["a", "b"], references: "parent")
            }
            
            let count = Int(sqlite3_limit(db.sqliteConnection, SQLITE_LIMIT_EXPR_DEPTH, -1))
            for index in 0..<count {
                try Parent(a: index, b: 1).insert(db)
                try Child(a: index, b: 1).insert(db)
            }
            
            let request = Parent
                .including(all: Parent.children)
                .asRequest(of: Row.self)
            
            let rows = try request.fetchAll(db)
            for (index, row) in rows.enumerated() {
                XCTAssertEqual(row.unscoped, ["a": index, "b": 1])
                XCTAssertEqual(row.prefetchedRows.keys, ["children"])
                XCTAssertEqual(row.prefetchedRows["children"]!.count, 1)
                XCTAssertEqual(
                    row.prefetchedRows["children"]![0],
                    ["a": index, "b": 1, "grdb_a": index, "grdb_b": 1])
            }
        }
    }
}
