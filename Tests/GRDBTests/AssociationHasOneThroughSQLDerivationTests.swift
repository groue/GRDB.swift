import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct A: TableRecord {
    static let b = belongsTo(B.self)
    static let c = hasOne(C.self, through: b, using: B.c)
    static let restrictedC = hasOne(RestrictedC.self, through: b, using: B.restrictedC)
    static let extendedC = hasOne(ExtendedC.self, through: b, using: B.extendedC)
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
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId"
                """)
            try assertEqualSQL(db, A.including(required: A.restrictedC), """
                SELECT "a".*, "c"."name" \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId"
                """)
            try assertEqualSQL(db, A.including(required: A.extendedC), """
                SELECT "a".*, "c".*, "c"."rowid" \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId"
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
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId"
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
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId"
                    """)
            }
            do {
                let aAlias = TableAlias()
                let request = A
                    .aliased(aAlias)
                    .including(required: A.c
                        .select(
                            Column("name"),
                            (Column("id") + aAlias[Column("id")]).forKey("foo")))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c"."name", "c"."id" + "a"."id" AS "foo" \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId"
                    """)
            }
        }
    }
    
    func testFilteredAssociationImpactsJoinOnClause() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = A.including(required: A.c.filter(Column("name") != nil))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON ("c"."id" = "b"."cId") AND ("c"."name" IS NOT NULL)
                    """)
            }
            do {
                let request = A.including(required: A.c.filter(key: 1))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON ("c"."id" = "b"."cId") AND ("c"."id" = 1)
                    """)
            }
            do {
                let request = A.including(required: A.c.filter(keys: [1, 2, 3]))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON ("c"."id" = "b"."cId") AND ("c"."id" IN (1, 2, 3))
                    """)
            }
            do {
                let request = A.including(required: A.c.filter(key: ["id": 1]))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON ("c"."id" = "b"."cId") AND ("c"."id" = 1)
                    """)
            }
            do {
                let request = A.including(required: A.c.filter(keys: [["id": 1], ["id": 2]]))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON ("c"."id" = "b"."cId") AND (("c"."id" = 1) OR ("c"."id" = 2))
                    """)
            }
            do {
                let cAlias = TableAlias(name: "customC")
                let request = A.including(required: A.c
                    .aliased(cAlias)
                    .filter(sql: "customC.name = ?", arguments: ["foo"]))
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "customC".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" "customC" ON ("customC"."id" = "b"."cId") AND (customC.name = 'foo')
                    """)
            }
        }
    }
    
    func testFilterAssociationInWhereClause() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let cAlias = TableAlias()
            let request = A
                .including(required: A.c.aliased(cAlias))
                .filter(cAlias[Column("name")] != nil)
            try assertEqualSQL(db, request, """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                WHERE "c"."name" IS NOT NULL
                """)
        }
    }
    
    func testOrderAssociation() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try assertEqualSQL(db, A.including(required: A.c.order(Column("name"))), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "c"."name"
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey()), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "c"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey()).orderByPrimaryKey(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "a"."id", "c"."id"
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey().reversed()).orderByPrimaryKey(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "a"."id", "c"."id" DESC
                """)
            try assertEqualSQL(db, A.including(required: A.c.order(Column("name"))).reversed(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "c"."name" DESC
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey()).reversed(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "c"."id" DESC
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey()).orderByPrimaryKey().reversed(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "a"."id" DESC, "c"."id" DESC
                """)
            try assertEqualSQL(db, A.including(required: A.c.orderByPrimaryKey().reversed()).orderByPrimaryKey().reversed(), """
                SELECT "a".*, "c".* \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId" \
                ORDER BY "a"."id" DESC, "c"."id"
                """)
        }
    }
}
