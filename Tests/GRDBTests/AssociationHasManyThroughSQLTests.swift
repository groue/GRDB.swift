import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test SQL generation

class AssociationHasManyThroughSQLTests: GRDBTestCase {
    
    func testBelongsToHasMany() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let c = hasMany(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasMany(C.self)
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
            
            try testHasManyWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testHasOneHasMany() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasOne(B.self)
            static let c = hasMany(C.self, through: b, using: B.c)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let c = hasMany(C.self)
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
            
            try testHasManyWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasManyBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasMany(B.self)
            static let c = hasMany(C.self, through: b, using: B.c)
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
            
            try testHasManyWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"id\" = \"b\".\"cId\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."cId" = "c"."id") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testHasManyHasOne() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = hasMany(B.self)
            static let c = hasMany(C.self, through: b, using: B.c)
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
            
            try testHasManyWithTwoSteps(
                db, ab: A.b, ac: A.c,
                bCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                cCondition: "\"c\".\"bId\" = \"b\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.c), """
                SELECT "c".* FROM "c" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    private func testHasManyWithTwoSteps<BAssociation, CAssociation>(
        _ db: Database,
        ab: BAssociation,
        ac: CAssociation,
        bCondition: String,
        cCondition: String) throws
        where
        BAssociation: Association,
        CAssociation: Association,
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
}
