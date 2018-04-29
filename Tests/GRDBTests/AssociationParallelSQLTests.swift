import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

// A -> B <- C
// A -> D
private struct A: TableRecord {
    static let databaseTableName = "a"
    static let b = belongsTo(B.self)
    static let d = belongsTo(D.self)
}

private struct B: TableRecord {
    static let a = hasOne(A.self)
    static let c = hasOne(C.self)
    static let databaseTableName = "b"
}

private struct C: TableRecord {
    static let databaseTableName = "c"
    static let b = belongsTo(B.self)
}

private struct D: TableRecord {
    static let a = hasOne(A.self)
    static let databaseTableName = "d"
}

/// Test SQL generation
class AssociationParallelSQLTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "b") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "d") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "a") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
                t.column("did", .integer).references("d")
            }
            try db.create(table: "c") { t in
                t.column("id", .integer).primaryKey()
                t.column("bid", .integer).references("b")
            }
        }
    }
    
    func testParallelTwoIncludingIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b).including(required: A.d), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(required: A.b).including(optional: A.d), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(optional: A.b).including(required: A.d), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(optional: A.b).including(optional: A.d), """
                SELECT "a".*, "b".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, B.including(required: B.a).including(required: B.c), """
                SELECT "b".*, "a".*, "c".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(required: B.a).including(optional: B.c), """
                SELECT "b".*, "a".*, "c".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(optional: B.a).including(required: B.c), """
                SELECT "b".*, "a".*, "c".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(optional: B.a).including(optional: B.c), """
                SELECT "b".*, "a".*, "c".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
        }
    }
    
    func testParallelTwoIncludingJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.b).joining(required: A.d), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(required: A.b).joining(optional: A.d), """
                SELECT "a".*, "b".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(optional: A.b).joining(required: A.d), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.including(optional: A.b).joining(optional: A.d), """
                SELECT "a".*, "b".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, B.including(required: B.a).joining(required: B.c), """
                SELECT "b".*, "a".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(required: B.a).joining(optional: B.c), """
                SELECT "b".*, "a".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(optional: B.a).joining(required: B.c), """
                SELECT "b".*, "a".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.including(optional: B.a).joining(optional: B.c), """
                SELECT "b".*, "a".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
        }
    }
    
    func testParallelTwoJoiningIncluding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b).including(required: A.d), """
                SELECT "a".*, "d".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(required: A.b).including(optional: A.d), """
                SELECT "a".*, "d".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(optional: A.b).including(required: A.d), """
                SELECT "a".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(optional: A.b).including(optional: A.d), """
                SELECT "a".*, "d".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, B.joining(required: B.a).including(required: B.c), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(required: B.a).including(optional: B.c), """
                SELECT "b".*, "c".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(optional: B.a).including(required: B.c), """
                SELECT "b".*, "c".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(optional: B.a).including(optional: B.c), """
                SELECT "b".*, "c".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
        }
    }
    
    func testParallelTwoJoiningJoining() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.joining(required: A.b).joining(required: A.d), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(required: A.b).joining(optional: A.d), """
                SELECT "a".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(optional: A.b).joining(required: A.d), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, A.joining(optional: A.b).joining(optional: A.d), """
                SELECT "a".* \
                FROM "a" \
                LEFT JOIN "b" ON ("b"."id" = "a"."bid") \
                LEFT JOIN "d" ON ("d"."id" = "a"."did")
                """)
            try assertEqualSQL(db, B.joining(required: B.a).joining(required: B.c), """
                SELECT "b".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(required: B.a).joining(optional: B.c), """
                SELECT "b".* \
                FROM "b" \
                JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(optional: B.a).joining(required: B.c), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                JOIN "c" ON ("c"."bid" = "b"."id")
                """)
            try assertEqualSQL(db, B.joining(optional: B.a).joining(optional: B.c), """
                SELECT "b".* \
                FROM "b" \
                LEFT JOIN "a" ON ("a"."bid" = "b"."id") \
                LEFT JOIN "c" ON ("c"."bid" = "b"."id")
                """)
        }
    }
}
