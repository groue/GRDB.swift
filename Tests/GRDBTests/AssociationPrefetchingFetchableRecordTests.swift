import XCTest
import GRDB

private struct A: TableRecord, FetchableRecord, Equatable {
    var cola1: Int64
    var cola2: String
    
    init(row: Row) throws {
        cola1 = try row["cola1"]
        cola2 = try row["cola2"]
    }
}
private struct B: TableRecord, FetchableRecord, Hashable {
    var colb1: Int64
    var colb2: Int64?
    var colb3: String
    
    init(row: Row) throws {
        colb1 = try row["colb1"]
        colb2 = try row["colb2"]
        colb3 = try row["colb3"]
    }
}
private struct C: TableRecord, FetchableRecord, Equatable {
    var colc1: Int64
    var colc2: Int64
    
    init(row: Row) throws {
        colc1 = try row["colc1"]
        colc2 = try row["colc2"]
    }
}
private struct D: TableRecord, FetchableRecord, Equatable {
    var cold1: Int64
    var cold2: Int64?
    var cold3: String
    
    init(row: Row) throws {
        cold1 = try row["cold1"]
        cold2 = try row["cold2"]
        cold3 = try row["cold3"]
    }
}

class AssociationPrefetchingFetchableRecordTests: GRDBTestCase {
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
                
                // Array
                do {
                    struct Record: FetchableRecord, Equatable {
                        var a: A
                        var bs: [B]
                        
                        init(a: A, bs: [B]) {
                            self.a = a
                            self.bs = bs
                        }
                        
                        init(row: Row) throws {
                            try self.init(a: A(row: row), bs: row["bs"])
                        }
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        try XCTAssertEqual(records, [
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
                        try XCTAssertEqual(record, Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]))
                    }
                }
                
                // Set
                do {
                    struct Record: FetchableRecord, Equatable {
                        var a: A
                        var bs: Set<B>
                        
                        init(a: A, bs: Set<B>) {
                            self.a = a
                            self.bs = bs
                        }
                        
                        init(row: Row) throws {
                            try self.init(a: A(row: row), bs: row["bs"])
                        }
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        try XCTAssertEqual(records, [
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
                        try XCTAssertEqual(record, Record(
                            a: A(row: ["cola1": 1, "cola2": "a1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]))
                    }
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
                
                struct Record: FetchableRecord, Equatable {
                    var a: A
                    var bs1: [B]
                    var bs2: [B]
                    
                    init(a: A, bs1: [B], bs2: [B]) {
                        self.a = a
                        self.bs1 = bs1
                        self.bs2 = bs2
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), bs1: row["bs1"], bs2: row["bs2"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var ds: [D]
                        
                        init(c: C, ds: [D]) {
                            self.c = c
                            self.ds = ds
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), ds: row["ds"])
                        }
                    }
                    var a: A
                    var cs: [CInfo]
                    
                    init(a: A, cs: [CInfo]) {
                        self.a = a
                        self.cs = cs
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs: row["cs"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                        .none()
                        .including(all: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var ds: [D]
                        
                        init(c: C, ds: [D]) {
                            self.c = c
                            self.ds = ds
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), ds: row["ds"])
                        }
                    }
                    var a: A
                    var cs: [CInfo]
                    
                    init(a: A, cs: [CInfo]) {
                        self.a = a
                        self.cs = cs
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs: row["cs"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var ds1: [D]
                        var ds2: [D]
                        
                        init(c: C, ds1: [D], ds2: [D]) {
                            self.c = c
                            self.ds1 = ds1
                            self.ds2 = ds2
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), ds1: row["ds1"], ds2: row["ds2"])
                        }
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                    
                    init(a: A, cs1: [CInfo], cs2: [CInfo]) {
                        self.a = a
                        self.cs1 = cs1
                        self.cs2 = cs2
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs1: row["cs1"], cs2: row["cs2"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var d: D
                        
                        init(c: C, d: D) {
                            self.c = c
                            self.d = d
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), d: row["d"])
                        }
                    }
                    var a: A
                    var cs: [CInfo]
                    
                    init(a: A, cs: [CInfo]) {
                        self.a = a
                        self.cs = cs
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs: row["cs"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                        .none()
                        .including(required: C
                            .hasMany(D.self)
                            .orderByPrimaryKey())
                        .orderByPrimaryKey())
                    .orderByPrimaryKey()
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var d: D
                        
                        init(c: C, d: D) {
                            self.c = c
                            self.d = d
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), d: row["d"])
                        }
                    }
                    var a: A
                    var cs: [CInfo]
                    
                    init(a: A, cs: [CInfo]) {
                        self.a = a
                        self.cs = cs
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs: row["cs"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                struct Record: FetchableRecord, Equatable {
                    struct CInfo: FetchableRecord, Equatable {
                        var c: C
                        var d1: D?
                        var d2: D
                        
                        init(c: C, d1: D?, d2: D) {
                            self.c = c
                            self.d1 = d1
                            self.d2 = d2
                        }
                        
                        init(row: Row) throws {
                            try self.init(c: C(row: row), d1: row["d1"], d2: row["d2"])
                        }
                    }
                    var a: A
                    var cs1: [CInfo]
                    var cs2: [CInfo]
                    
                    init(a: A, cs1: [CInfo], cs2: [CInfo]) {
                        self.a = a
                        self.cs1 = cs1
                        self.cs2 = cs2
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), cs1: row["cs1"], cs2: row["cs2"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                struct Record: FetchableRecord, Equatable {
                    var a: A
                    var ds: [D]
                    
                    init(a: A, ds: [D]) {
                        self.a = a
                        self.ds = ds
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), ds: row["ds"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                struct Record: FetchableRecord, Equatable {
                    var a: A
                    var ds1: [D]
                    var ds2: [D]
                    var ds3: [D]
                    
                    init(a: A, ds1: [D], ds2: [D], ds3: [D]) {
                        self.a = a
                        self.ds1 = ds1
                        self.ds2 = ds2
                        self.ds3 = ds3
                    }
                    
                    init(row: Row) throws {
                        try self.init(a: A(row: row), ds1: row["ds1"], ds2: row["ds2"], ds3: row["ds3"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                // Record (nested)
                do {
                    struct Record: FetchableRecord, Equatable {
                        struct AInfo: FetchableRecord, Equatable {
                            var a: A
                            var cs: [C]
                            
                            init(a: A, cs: [C]) {
                                self.a = a
                                self.cs = cs
                            }
                            
                            init(row: Row) throws {
                                try self.init(a: A(row: row), cs: row["cs"])
                            }
                        }
                        var b: B
                        var a: AInfo?
                        
                        init(b: B, a: AInfo?) {
                            self.b = b
                            self.a = a
                        }
                        
                        init(row: Row) throws {
                            try self.init(b: B(row: row), a: row["a"])
                        }
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        try XCTAssertEqual(records, [
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
                        try XCTAssertEqual(record, Record(
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
                    struct Record: FetchableRecord, Equatable {
                        var b: B
                        var a: A?
                        var cs: [C] // not optional
                        
                        init(b: B, a: A?, cs: [C]) {
                            self.b = b
                            self.a = a
                            self.cs = cs
                        }
                        
                        init(row: Row) throws {
                            try self.init(b: B(row: row), a: row["a"], cs: row["cs"])
                        }
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        try XCTAssertEqual(records, [
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
                        try XCTAssertEqual(record, Record(
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
                
                struct Record: FetchableRecord, Equatable {
                    struct AInfo: FetchableRecord, Equatable {
                        var a: A
                        var cs1: [C]
                        var cs2: [C]
                        
                        init(a: A, cs1: [C], cs2: [C]) {
                            self.a = a
                            self.cs1 = cs1
                            self.cs2 = cs2
                        }
                        
                        init(row: Row) throws {
                            try self.init(a: A(row: row), cs1: row["cs1"], cs2: row["cs2"])
                        }
                    }
                    var b: B
                    var a1: AInfo?
                    var a2: AInfo?
                    
                    init(b: B, a1: AInfo?, a2: AInfo?) {
                        self.b = b
                        self.a1 = a1
                        self.a2 = a2
                    }
                    
                    init(row: Row) throws {
                        try self.init(b: B(row: row), a1: row["a1"], a2: row["a2"])
                    }
                }
                
                // Record.fetchAll
                do {
                    let records = try Record.fetchAll(db, request)
                    try XCTAssertEqual(records, [
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
                    try XCTAssertEqual(record, Record(
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
                
                // Record (flat)
                do {
                    struct Record: FetchableRecord, Equatable {
                        var d: D
                        var bs: [B] // not optional
                        
                        init(d: D, bs: [B]) {
                            self.d = d
                            self.bs = bs
                        }
                        
                        init(row: Row) throws {
                            try self.init(d: D(row: row), bs: row["bs"])
                        }
                    }
                    
                    // Record.fetchAll
                    do {
                        let records = try Record.fetchAll(db, request)
                        try XCTAssertEqual(records, [
                            Record(
                                d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                                bs: [
                                    B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                    B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                                ]),
                            Record(
                                d: D(row: ["cold1": 11, "cold2": 8, "cold3": "d2"]),
                                bs: [
                                    B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                ]),
                            Record(
                                d: D(row: ["cold1": 12, "cold2": 8, "cold3": "d3"]),
                                bs: [
                                    B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                ]),
                            Record(
                                d: D(row: ["cold1": 13, "cold2": 9, "cold3": "d4"]),
                                bs: [
                                    B(row: ["colb1": 6, "colb2": 2, "colb3": "b3"]),
                                ]),
                            Record(
                                d: D(row: ["cold1": 14, "cold2": nil, "cold3": "d5"]),
                                bs: []),
                            ])
                    }
                    
                    // Record.fetchOne
                    do {
                        let record = try Record.fetchOne(db, request)!
                        try XCTAssertEqual(record, Record(
                            d: D(row: ["cold1": 10, "cold2": 7, "cold3": "d1"]),
                            bs: [
                                B(row: ["colb1": 4, "colb2": 1, "colb3": "b1"]),
                                B(row: ["colb1": 5, "colb2": 1, "colb3": "b2"]),
                            ]))
                    }
                }
            }
        }
    }
}
