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
private struct B: TableRecord, FetchableRecord, Decodable, Hashable {
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

class AssociationPrefetchingObservationTests: GRDBTestCase {
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
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
                
                try XCTAssertEqual(request.databaseRegion(db).description, "TODO")
            }
        }
    }
}
