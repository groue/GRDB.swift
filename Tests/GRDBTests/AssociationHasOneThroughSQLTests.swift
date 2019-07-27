import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test SQL generation

class AssociationHasOneThroughSQLTests: GRDBTestCase {
    
    // MARK: - Two Steps
    
    func testBelongsToBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
        }
        struct C: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testBelongsToHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
        }
        struct C: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testHasOneBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
        }
        struct C: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
                t.column("aId").references("a")
            }
            
            try testHasOneWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasOneHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
        }
        struct C: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId").references("a")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    private func testHasOneWithTwoSteps<BAssociation, CAssociation>(
        _ db: Database,
        ab: BAssociation,
        ac: CAssociation,
        bCondition: String,
        cCondition: String) throws
        where
        BAssociation: AssociationToOne,
        CAssociation: AssociationToOne,
        BAssociation.OriginRowDecoder == CAssociation.OriginRowDecoder
    {
        let A = BAssociation.OriginRowDecoder.self
        
        do {
            try assertEqualSQL(db, A.including(optional: ac), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(required: ac), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(optional: ac), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(required: ac), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
        }
        do {
            try assertEqualSQL(db, A.including(optional: ac).including(optional: ab), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(optional: ac).including(required: ab), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(optional: ac).joining(optional: ab), """
                SELECT "a".*, "c".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(optional: ac).joining(required: ab), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
        }
        do {
            try assertEqualSQL(db, A.including(required: ac).including(optional: ab), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(required: ac).including(required: ab), """
                SELECT "a".*, "b".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(required: ac).joining(optional: ab), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.including(required: ac).joining(required: ab), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
        }
        do {
            try assertEqualSQL(db, A.joining(optional: ac).including(optional: ab), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(optional: ac).including(required: ab), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(optional: ac).joining(optional: ab), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(optional: ac).joining(required: ab), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                LEFT JOIN "c" ON \(cCondition)
                """)
        }
        do {
            try assertEqualSQL(db, A.joining(required: ac).including(optional: ab), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(required: ac).including(required: ab), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(required: ac).joining(optional: ab), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
            try assertEqualSQL(db, A.joining(required: ac).joining(required: ab), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON \(bCondition) \
                JOIN "c" ON \(cCondition)
                """)
        }
    }
    
    // MARK: - Three Steps
    
    func testBelongsToBelongsToBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = belongsTo(D.self)
        }
        struct D: TableRecord {
        }

        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dId").references("d")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"",
                dCondition: "\"d\".\"id\" = \"c\".\"dId\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testBelongsToBelongsToHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = hasOne(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"",
                dCondition: "\"d\".\"cId\" = \"c\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testBelongsToHasOneBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = belongsTo(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
                t.column("dId").references("d")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dCondition: "\"d\".\"id\" = \"c\".\"dId\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testBelongsToHasOneHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = hasOne(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dCondition: "\"d\".\"cId\" = \"c\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testHasOneBelongsToBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = belongsTo(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dId").references("d")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId").references("a")
                t.column("cId").references("c")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"",
                dCondition: "\"d\".\"id\" = \"c\".\"dId\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasOneBelongsToHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = hasOne(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId").references("a")
                t.column("cId").references("c")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"",
                dCondition: "\"d\".\"cId\" = \"c\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasOneHasOneBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = belongsTo(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId").references("a")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
                t.column("dId").references("d")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dCondition: "\"d\".\"id\" = \"c\".\"dId\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasOneHasOneHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
        }
        struct C: TableRecord {
            static let d = hasOne(D.self)
        }
        struct D: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId").references("a")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            
            try testHasOneWithThreeSteps(
                db, b: A.b, c: A.c, dThroughC: A.dThroughC, dThroughB: A.dThroughB,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dCondition: "\"d\".\"cId\" = \"c\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.dThroughC), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    private func testHasOneWithThreeSteps<BAssociation, CAssociation, DCAssociation, DBAssociation>(
        _ db: Database,
        b: BAssociation,
        c: CAssociation,
        dThroughC: DCAssociation,
        dThroughB: DBAssociation,
        bCondition: String,
        cCondition: String,
        dCondition: String) throws
        where
        BAssociation: AssociationToOne,
        CAssociation: AssociationToOne,
        DCAssociation: AssociationToOne,
        DBAssociation: AssociationToOne,
        BAssociation.OriginRowDecoder == CAssociation.OriginRowDecoder,
        BAssociation.OriginRowDecoder == DCAssociation.OriginRowDecoder,
        BAssociation.OriginRowDecoder == DBAssociation.OriginRowDecoder
    {
        let A = CAssociation.OriginRowDecoder.self
        
        do {
            for request in [
                A.including(optional: dThroughC),
                A.including(optional: dThroughB)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "d".* \
                    FROM "a" \
                    LEFT JOIN "b" ON \(bCondition) \
                    LEFT JOIN "c" ON \(cCondition) \
                    LEFT JOIN "d" ON \(dCondition)
                    """)
            }
            for request in [
                A.including(required: dThroughC),
                A.including(required: dThroughB)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "d".* \
                    FROM "a" \
                    JOIN "b" ON \(bCondition) \
                    JOIN "c" ON \(cCondition) \
                    JOIN "d" ON \(dCondition)
                    """)
            }
            for request in [
                A.joining(optional: dThroughC),
                A.joining(optional: dThroughB)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON \(bCondition) \
                    LEFT JOIN "c" ON \(cCondition) \
                    LEFT JOIN "d" ON \(dCondition)
                    """)
            }
            for request in [
                A.joining(required: dThroughC),
                A.joining(required: dThroughB)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON \(bCondition) \
                    JOIN "c" ON \(cCondition) \
                    JOIN "d" ON \(dCondition)
                    """)
            }
        }
        
        do {
            do {
                for request in [
                    A.including(optional: dThroughC).including(optional: b),
                    A.including(optional: dThroughB).including(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).including(optional: b),
                    A.including(required: dThroughB).including(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).including(optional: b),
                    A.joining(optional: dThroughB).including(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).including(optional: b),
                    A.joining(required: dThroughB).including(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).including(required: b),
                    A.including(optional: dThroughB).including(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).including(required: b),
                    A.including(required: dThroughB).including(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).including(required: b),
                    A.joining(optional: dThroughB).including(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).including(required: b),
                    A.joining(required: dThroughB).including(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).joining(optional: b),
                    A.including(optional: dThroughB).joining(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).joining(optional: b),
                    A.including(required: dThroughB).joining(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).joining(optional: b),
                    A.joining(optional: dThroughB).joining(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).joining(optional: b),
                    A.joining(required: dThroughB).joining(optional: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).joining(required: b),
                    A.including(optional: dThroughB).joining(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).joining(required: b),
                    A.including(required: dThroughB).joining(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).joining(required: b),
                    A.joining(optional: dThroughB).joining(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).joining(required: b),
                    A.joining(required: dThroughB).joining(required: b)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
        }

        do {
            do {
                for request in [
                    A.including(optional: dThroughC).including(optional: c),
                    A.including(optional: dThroughB).including(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).including(optional: c),
                    A.including(required: dThroughB).including(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).including(optional: c),
                    A.joining(optional: dThroughB).including(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).including(optional: c),
                    A.joining(required: dThroughB).including(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).including(required: c),
                    A.including(optional: dThroughB).including(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).including(required: c),
                    A.including(required: dThroughB).including(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).including(required: c),
                    A.joining(optional: dThroughB).including(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).including(required: c),
                    A.joining(required: dThroughB).including(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).joining(optional: c),
                    A.including(optional: dThroughB).joining(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).joining(optional: c),
                    A.including(required: dThroughB).joining(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).joining(optional: c),
                    A.joining(optional: dThroughB).joining(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bCondition) \
                        LEFT JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).joining(optional: c),
                    A.joining(required: dThroughB).joining(optional: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dThroughC).joining(required: c),
                    A.including(optional: dThroughB).joining(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.including(required: dThroughC).joining(required: c),
                    A.including(required: dThroughB).joining(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dThroughC).joining(required: c),
                    A.joining(optional: dThroughB).joining(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        LEFT JOIN "d" ON \(dCondition)
                        """)
                }
                for request in [
                    A.joining(required: dThroughC).joining(required: c),
                    A.joining(required: dThroughB).joining(required: c)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bCondition) \
                        JOIN "c" ON \(cCondition) \
                        JOIN "d" ON \(dCondition)
                        """)
                }
            }
        }
    }
    
    // MARK: - Four Steps
    
    func testBelongsToBelongsToBelongsToBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(C.self, through: b, using: B.c)
            static let dThroughB = hasOne(D.self, through: b, using: B.d)
            static let dThroughC = hasOne(D.self, through: c, using: C.d)
            static let eThroughBThroughC = hasOne(E.self, through: b, using: B.eThroughC)
            static let eThroughBThroughD = hasOne(E.self, through: b, using: B.eThroughD)
            static let eThroughC = hasOne(E.self, through: c, using: C.e)
            static let eThroughDThroughB = hasOne(E.self, through: dThroughB, using: D.e)
            static let eThroughDThroughC = hasOne(E.self, through: dThroughC, using: D.e)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(D.self, through: c, using: C.d)
            static let eThroughC = hasOne(E.self, through: c, using: C.e)
            static let eThroughD = hasOne(E.self, through: d, using: D.e)
        }
        struct C: TableRecord {
            static let d = belongsTo(D.self)
            static let e = hasOne(E.self, through: d, using: D.e)
        }
        struct D: TableRecord {
            static let e = belongsTo(E.self)
        }
        struct E: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "e") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("eId").references("e")
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("dId").references("d")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
            
            let associations = [
                A.eThroughBThroughC,
                A.eThroughBThroughD,
                A.eThroughC,
                A.eThroughDThroughB,
                A.eThroughDThroughC,
            ]
            for association in associations {
                try assertEqualSQL(db, A.including(required: association), """
                    SELECT "a".*, "e".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId" \
                    JOIN "d" ON "d"."id" = "c"."dId" \
                    JOIN "e" ON "e"."id" = "d"."eId"
                    """)
                try assertEqualSQL(db, A.including(optional: association), """
                    SELECT "a".*, "e".* \
                    FROM "a" \
                    LEFT JOIN "b" ON "b"."id" = "a"."bId" \
                    LEFT JOIN "c" ON "c"."id" = "b"."cId" \
                    LEFT JOIN "d" ON "d"."id" = "c"."dId" \
                    LEFT JOIN "e" ON "e"."id" = "d"."eId"
                    """)
                try assertEqualSQL(db, A.joining(required: association), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId" \
                    JOIN "d" ON "d"."id" = "c"."dId" \
                    JOIN "e" ON "e"."id" = "d"."eId"
                    """)
                try assertEqualSQL(db, A.joining(optional: association), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON "b"."id" = "a"."bId" \
                    LEFT JOIN "c" ON "c"."id" = "b"."cId" \
                    LEFT JOIN "d" ON "d"."id" = "c"."dId" \
                    LEFT JOIN "e" ON "e"."id" = "d"."eId"
                    """)
                try assertEqualSQL(db, A().request(for: association), """
                    SELECT "e".* \
                    FROM "e" \
                    JOIN "d" ON "d"."eId" = "e"."id" \
                    JOIN "c" ON "c"."dId" = "d"."id" \
                    JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."id" = 1)
                    """)
            }
        }
    }
}
