import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: TableRecord {
    static let b = belongsTo(B.self)
    static let c = hasOne(B.c, through: b)
    static let restrictedC = hasOne(B.restrictedC, through: b)
    static let extendedC = hasOne(B.extendedC, through: b)
}

private struct B: TableRecord {
    static let c = belongsTo(C.self)
    static let restrictedC = belongsTo(RestrictedC.self)
    static let extendedC = belongsTo(ExtendedC.self)
}

private struct C: TableRecord {
}

private struct RestrictedC : TableRecord {
    static let databaseTableName = "c"
    static let databaseSelection: [SQLSelectable] = [Column("name")]
}

private struct ExtendedC : TableRecord {
    static let databaseTableName = "c"
    static let databaseSelection: [SQLSelectable] = [AllColumns(), Column.rowID]
}

/// Test SQL generation
class AssociationHasOneThroughSQLDerivationTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("cId").references("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bId").references("b")
            }
        }
    }
    
    func testDefaultSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.c), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bId") \
                JOIN "c" ON ("c"."id" = "b"."cId")
                """)
            try assertEqualSQL(db, A.including(required: A.restrictedC), """
                SELECT "a".*, "c"."name" \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bId") \
                JOIN "c" ON ("c"."id" = "b"."cId")
                """)
            try assertEqualSQL(db, A.including(required: A.extendedC), """
                SELECT "a".*, "c".*, "c"."rowid" \
                FROM "a" \
                JOIN "b" ON ("b"."id" = "a"."bId") \
                JOIN "c" ON ("c"."id" = "b"."cId")
                """)
        }
    }
    
    func testCustomSelection() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = A.including(required: A.c
                    .select(Column("name")))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c"."name" \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                let request = A.including(required: A.c
                    .select(
                        AllColumns(),
                        Column.rowID))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".*, "c"."rowid" \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
            do {
                let aAlias = TableAlias()
                let request = A
                    .aliased(aAlias)
                    .including(required: A.c
                        .select(
                            Column("name"),
                            (Column("id") + aAlias[Column("id")]).aliased("foo")))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c"."name", ("c"."id" + "a"."id") AS "foo" \
                    FROM "a" \
                    JOIN "b" ON ("b"."id" = "a"."bId") \
                    JOIN "c" ON ("c"."id" = "b"."cId")
                    """)
            }
        }
    }
}
