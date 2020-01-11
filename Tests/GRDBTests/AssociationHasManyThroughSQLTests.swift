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
    
    func testAssociationFilteredByOtherAssociation() throws {
        struct Pet: TableRecord {
            static let child = belongsTo(Child.self)
        }
        struct Toy: TableRecord { }
        struct Child: TableRecord {
            static let toy = hasOne(Toy.self)
            static let pets = hasMany(Pet.self)
        }
        struct Parent: TableRecord, EncodableRecord {
            static let children = hasMany(Child.self)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "child") { t in
                t.column("parentId", .integer).references("parent")
            }
            try db.create(table: "toy") { t in
                t.column("childId", .integer).references("child")
            }
            try db.create(table: "pet") { t in
                t.column("childId", .integer).references("child")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasMany(
                    Pet.self,
                    through: Parent.children.joining(required: Child.toy),
                    using: Child.pets)
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "pet".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."parentId" = "parent"."id" \
                    JOIN "toy" ON "toy"."childId" = "child"."rowid" \
                    JOIN "pet" ON "pet"."childId" = "child"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."parentId" = "parent"."id" \
                    JOIN "toy" ON "toy"."childId" = "child"."rowid" \
                    JOIN "pet" ON "pet"."childId" = "child"."rowid"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" ON ("child"."rowid" = "pet"."childId") AND ("child"."parentId" = 1) \
                    JOIN "toy" ON "toy"."childId" = "child"."rowid"
                    """)
            }
            do {
                let association = Parent.hasMany(
                    Pet.self,
                    through: Parent.children.filter(sql: "1 + 1"),
                    using: Child.pets.joining(required: Pet.child.filter(sql: "1").joining(required: Child.toy)))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "pet".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."rowid"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" "child1" ON ("child1"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1 + 1) AND ("child2"."parentId" = 1)
                    """)
            }
            do {
                let association = Parent.hasMany(
                    Pet.self,
                    through: Parent.children.filter(sql: "1 + 1"),
                    using: Child.pets)
                    .joining(required: Pet.child.filter(sql: "1").joining(required: Child.toy))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "pet".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."rowid"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" "child1" ON ("child1"."rowid" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child1"."rowid" \
                    JOIN "child" "child2" ON ("child2"."rowid" = "pet"."childId") AND (1 + 1) AND ("child2"."parentId" = 1)
                    """)
            }
        }
    }
}
