import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test SQL generation

class AssociationHasOneThroughSQLTests: GRDBTestCase {
    
    func testBelongsToBelongsTo() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
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
            
            do {
                try assertEqualSQL(db, A.including(optional: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
        }
    }
    
    func testBelongsToHasOne() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
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
            
            do {
                try assertEqualSQL(db, A.including(optional: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
        }
    }
    
    func testHasOneBelongsTo() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
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
            
            do {
                try assertEqualSQL(db, A.including(optional: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
        }
    }
    
    func testHasOneHasOne() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
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
            
            do {
                try assertEqualSQL(db, A.including(optional: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(optional: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.including(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(optional: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.including(required: A.c).joining(required: A.b), """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(optional: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(optional: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    LEFT JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
            do {
                try assertEqualSQL(db, A.joining(required: A.c).including(optional: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).including(required: A.b), """
                    SELECT "a".*, "b".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(optional: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
                try assertEqualSQL(db, A.joining(required: A.c).joining(required: A.b), """
                    SELECT "a".* \
                    FROM "a" \
                    JOIN "b" ON ("b"."aId" = "a"."id") \
                    JOIN "c" ON ("c"."bId" = "b"."id")
                    """)
            }
        }
    }
    
    func testBelongsToBelongsToBelongsTo() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
            }
        }
    }
    
    func testBelongsToBelongsToHasOne() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
            }
        }
    }
    
    func testBelongsToHasOneBelongsTo() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
            }
        }
    }
    
    func testBelongsToHasOneHasOne() throws {
        struct A: TableRecord {
            static let b = belongsTo(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."id" = "a"."bId") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."id" = "a"."bId") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
            }
        }
    }
    
    func testHasOneBelongsToBelongsTo() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
            }
        }
    }
    
    func testHasOneBelongsToHasOne() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = belongsTo(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."id" = "b"."cId") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."id" = "b"."cId") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
            }
        }
    }
    
    func testHasOneHasOneBelongsTo() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."id" = "c"."dId")
                        """)
                }
            }
        }
    }
    
    func testHasOneHasOneHasOne() throws {
        struct A: TableRecord {
            static let b = hasOne(B.self)
            static let c = hasOne(B.c, through: b)
            static let d1 = hasOne(C.d, through: c)
            static let d2 = hasOne(B.d, through: b)
        }
        struct B: TableRecord {
            static let c = hasOne(C.self)
            static let d = hasOne(C.d, through: c)
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
            
            do {
                for request in [
                    A.including(optional: A.d1),
                    A.including(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.including(required: A.d1),
                    A.including(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".*, "d".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(optional: A.d1),
                    A.joining(optional: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        LEFT JOIN "b" ON ("b"."aId" = "a"."id") \
                        LEFT JOIN "c" ON ("c"."bId" = "b"."id") \
                        LEFT JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
                for request in [
                    A.joining(required: A.d1),
                    A.joining(required: A.d2)]
                {
                    try assertEqualSQL(db, request, """
                        SELECT "a".* \
                        FROM "a" \
                        JOIN "b" ON ("b"."aId" = "a"."id") \
                        JOIN "c" ON ("c"."bId" = "b"."id") \
                        JOIN "d" ON ("d"."cId" = "c"."id")
                        """)
                }
            }
        }
    }
}
