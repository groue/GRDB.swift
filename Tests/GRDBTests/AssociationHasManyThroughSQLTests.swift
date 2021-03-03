import XCTest
import GRDB

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
        BAssociation.OriginRowDecoder: TableRecord,
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
                t.autoIncrementedPrimaryKey("id")
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
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    JOIN "pet" ON "pet"."childId" = "child"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."parentId" = "parent"."id" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    JOIN "pet" ON "pet"."childId" = "child"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" ON ("child"."id" = "pet"."childId") AND ("child"."parentId" = 1) \
                    JOIN "toy" ON "toy"."childId" = "child"."id"
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
                    JOIN "pet" ON "pet"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" "child1" ON ("child1"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1 + 1) AND ("child2"."parentId" = 1)
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
                    JOIN "pet" ON "pet"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" "child1" ON ("child1"."parentId" = "parent"."id") AND (1 + 1) \
                    JOIN "pet" ON "pet"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child2"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "pet".* \
                    FROM "pet" \
                    JOIN "child" "child1" ON ("child1"."id" = "pet"."childId") AND (1) \
                    JOIN "toy" ON "toy"."childId" = "child1"."id" \
                    JOIN "child" "child2" ON ("child2"."id" = "pet"."childId") AND (1 + 1) AND ("child2"."parentId" = 1)
                    """)
            }
        }
    }
    
    // MARK: - Three Steps
    
    func testHasManyHasManyHasMany() throws {
        struct A: TableRecord, EncodableRecord {
            static let bs = hasMany(B.self)
            static let cs = hasMany(C.self, through: bs, using: B.cs)
            static let dsThroughCs = hasMany(D.self, through: cs, using: C.ds)
            static let dsThroughBs = hasMany(D.self, through: bs, using: B.ds)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let cs = hasMany(C.self)
            static let ds = hasMany(D.self, through: cs, using: C.ds)
        }
        struct C: TableRecord {
            static let ds = hasMany(D.self)
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
            
            try testHasManyWithThreeSteps(
                db, bs: A.bs, cs: A.cs, dsThroughCs: A.dsThroughCs, dsThroughBs: A.dsThroughBs,
                bsCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                csCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dsCondition: "\"d\".\"cId\" = \"c\".\"id\"")

            try assertEqualSQL(db, A().request(for: A.dsThroughCs), """
                SELECT "d".* \
                FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dsThroughBs), """
                SELECT "d".* \
                FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    func testBelongsToHasManyHasMany() throws {
        struct A: TableRecord, EncodableRecord {
            static let b = belongsTo(B.self)
            static let cs = hasMany(C.self, through: b, using: B.cs)
            static let dsThroughCs = hasMany(D.self, through: cs, using: C.ds)
            static let dsThroughB = hasMany(D.self, through: b, using: B.ds)
            func encode(to container: inout PersistenceContainer) {
                container["bId"] = 1
            }
        }
        struct B: TableRecord {
            static let cs = hasMany(C.self)
            static let ds = hasMany(D.self, through: cs, using: C.ds)
        }
        struct C: TableRecord {
            static let ds = hasMany(D.self)
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
            
            try testHasManyWithThreeSteps(
                db, bs: A.b, cs: A.cs, dsThroughCs: A.dsThroughCs, dsThroughBs: A.dsThroughB,
                bsCondition: "\"b\".\"id\" = \"a\".\"bId\"",
                csCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dsCondition: "\"d\".\"cId\" = \"c\".\"id\"")
            
            try assertEqualSQL(db, A().request(for: A.dsThroughCs), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dsThroughB), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."id" = "d"."cId" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."id" = 1)
                """)
        }
    }
    
    func testHasManyHasManyBelongsTo() throws {
        struct A: TableRecord, EncodableRecord {
            static let bs = hasMany(B.self)
            static let cs = hasMany(C.self, through: bs, using: B.cs)
            static let dsThroughCs = hasMany(D.self, through: cs, using: C.d)
            static let dsThroughBs = hasMany(D.self, through: bs, using: B.ds)
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        struct B: TableRecord {
            static let cs = hasMany(C.self)
            static let ds = hasMany(D.self, through: cs, using: C.d)
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
            
            try testHasManyWithThreeSteps(
                db, bs: A.bs, cs: A.cs, dsThroughCs: A.dsThroughCs, dsThroughBs: A.dsThroughBs,
                bsCondition: "\"b\".\"aId\" = \"a\".\"id\"",
                csCondition: "\"c\".\"bId\" = \"b\".\"id\"",
                dsCondition: "\"d\".\"id\" = \"c\".\"dId\"")
            
            try assertEqualSQL(db, A().request(for: A.dsThroughCs), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
            try assertEqualSQL(db, A().request(for: A.dsThroughBs), """
                SELECT "d".* FROM "d" \
                JOIN "c" ON "c"."dId" = "d"."id" \
                JOIN "b" ON ("b"."id" = "c"."bId") AND ("b"."aId" = 1)
                """)
        }
    }
    
    private func testHasManyWithThreeSteps<BsAssociation, CsAssociation, DsCsAssociation, DsBsAssociation>(
        _ db: Database,
        bs: BsAssociation,
        cs: CsAssociation,
        dsThroughCs: DsCsAssociation,
        dsThroughBs: DsBsAssociation,
        bsCondition: String,
        csCondition: String,
        dsCondition: String) throws
        where
        BsAssociation: Association,
        CsAssociation: Association,
        DsCsAssociation: Association,
        DsBsAssociation: Association,
        BsAssociation.OriginRowDecoder: TableRecord,
        BsAssociation.OriginRowDecoder == CsAssociation.OriginRowDecoder,
        BsAssociation.OriginRowDecoder == DsCsAssociation.OriginRowDecoder,
        BsAssociation.OriginRowDecoder == DsBsAssociation.OriginRowDecoder
    {
        let A = CsAssociation.OriginRowDecoder.self
        
        do {
            for request in [
                A.including(optional: dsThroughCs),
                A.including(optional: dsThroughBs)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "d".* \
                    FROM "a" \
                    LEFT JOIN "b" ON \(bsCondition) \
                    LEFT JOIN "c" ON \(csCondition) \
                    LEFT JOIN "d" ON \(dsCondition)
                    """)
            }
            for request in [
                A.including(required: dsThroughCs),
                A.including(required: dsThroughBs)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "d".* \
                    FROM "a" \
                    JOIN "b" ON \(bsCondition) \
                    JOIN "c" ON \(csCondition) \
                    JOIN "d" ON \(dsCondition)
                    """)
            }
            for request in [
                A.joining(optional: dsThroughCs),
                A.joining(optional: dsThroughBs)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON \(bsCondition) \
                    LEFT JOIN "c" ON \(csCondition) \
                    LEFT JOIN "d" ON \(dsCondition)
                    """)
            }
            for request in [
                A.joining(required: dsThroughCs),
                A.joining(required: dsThroughBs)]
            {
                try assertEqualSQL(db, request, """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON \(bsCondition) \
                    JOIN "c" ON \(csCondition) \
                    JOIN "d" ON \(dsCondition)
                    """)
            }
        }
        
        do {
            do {
                for request in [
                    A.including(optional: dsThroughCs).including(optional: bs),
                    A.including(optional: dsThroughBs).including(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).including(optional: bs),
                    A.including(required: dsThroughBs).including(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).including(optional: bs),
                    A.joining(optional: dsThroughBs).including(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).including(optional: bs),
                    A.joining(required: dsThroughBs).including(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).including(required: bs),
                    A.including(optional: dsThroughBs).including(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).including(required: bs),
                    A.including(required: dsThroughBs).including(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).including(required: bs),
                    A.joining(optional: dsThroughBs).including(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).including(required: bs),
                    A.joining(required: dsThroughBs).including(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "b".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).joining(optional: bs),
                    A.including(optional: dsThroughBs).joining(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).joining(optional: bs),
                    A.including(required: dsThroughBs).joining(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).joining(optional: bs),
                    A.joining(optional: dsThroughBs).joining(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).joining(optional: bs),
                    A.joining(required: dsThroughBs).joining(optional: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).joining(required: bs),
                    A.including(optional: dsThroughBs).joining(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).joining(required: bs),
                    A.including(required: dsThroughBs).joining(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).joining(required: bs),
                    A.joining(optional: dsThroughBs).joining(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).joining(required: bs),
                    A.joining(required: dsThroughBs).joining(required: bs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
        }

        do {
            do {
                for request in [
                    A.including(optional: dsThroughCs).including(optional: cs),
                    A.including(optional: dsThroughBs).including(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).including(optional: cs),
                    A.including(required: dsThroughBs).including(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).including(optional: cs),
                    A.joining(optional: dsThroughBs).including(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).including(optional: cs),
                    A.joining(required: dsThroughBs).including(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).including(required: cs),
                    A.including(optional: dsThroughBs).including(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).including(required: cs),
                    A.including(required: dsThroughBs).including(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).including(required: cs),
                    A.joining(optional: dsThroughBs).including(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).including(required: cs),
                    A.joining(required: dsThroughBs).including(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "c".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).joining(optional: cs),
                    A.including(optional: dsThroughBs).joining(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).joining(optional: cs),
                    A.including(required: dsThroughBs).joining(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).joining(optional: cs),
                    A.joining(optional: dsThroughBs).joining(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON \(bsCondition) \
                        LEFT JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).joining(optional: cs),
                    A.joining(required: dsThroughBs).joining(optional: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
            
            do {
                for request in [
                    A.including(optional: dsThroughCs).joining(required: cs),
                    A.including(optional: dsThroughBs).joining(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.including(required: dsThroughCs).joining(required: cs),
                    A.including(required: dsThroughBs).joining(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(optional: dsThroughCs).joining(required: cs),
                    A.joining(optional: dsThroughBs).joining(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        LEFT JOIN "d" ON \(dsCondition)
                        """)
                }
                for request in [
                    A.joining(required: dsThroughCs).joining(required: cs),
                    A.joining(required: dsThroughBs).joining(required: cs)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON \(bsCondition) \
                        JOIN "c" ON \(csCondition) \
                        JOIN "d" ON \(dsCondition)
                        """)
                }
            }
        }
    }
}
