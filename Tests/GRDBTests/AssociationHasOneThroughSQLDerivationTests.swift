import XCTest
import GRDB

private struct A: TableRecord {
    static let b = belongsTo(B.self)
    static let c = hasOne(C.self, through: b, using: B.c)
    static let restrictedC1 = hasOne(RestrictedC1.self, through: b, using: B.restrictedC1)
    static let restrictedC2 = hasOne(RestrictedC2.self, through: b, using: B.restrictedC2)
    static let extendedC = hasOne(ExtendedC.self, through: b, using: B.extendedC)
    
    enum Columns {
        static let id = Column("id")
        static let bid = Column("bid")
    }
}

private struct B: TableRecord {
    static let c = belongsTo(C.self)
    static let restrictedC1 = belongsTo(RestrictedC1.self)
    static let restrictedC2 = belongsTo(RestrictedC2.self)
    static let extendedC = belongsTo(ExtendedC.self)
    
    enum Columns {
        static let id = Column("id")
        static let cid = Column("cid")
    }
}

private struct C: TableRecord {
    enum Columns {
        static let id = Column("id")
        static let name = Column("name")
    }
}

private struct RestrictedC1 : TableRecord {
    static let databaseTableName = "c"
    static var databaseSelection: [any SQLSelectable] { [Column("name")] }
}

private struct RestrictedC2 : TableRecord {
    static let databaseTableName = "c"
    static var databaseSelection: [any SQLSelectable] { [.allColumns(excluding: ["id"])] }
}

private struct ExtendedC : TableRecord {
    static let databaseTableName = "c"
    static var databaseSelection: [any SQLSelectable] { [.allColumns, .rowID] }
}

/// Test SQL generation
class AssociationHasOneThroughSQLDerivationTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("c")
            }
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("b")
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
            try assertEqualSQL(db, A.including(required: A.restrictedC1), """
                SELECT "a".*, "c"."name" \
                FROM "a" \
                JOIN "b" ON "b"."id" = "a"."bId" \
                JOIN "c" ON "c"."id" = "b"."cId"
                """)
            try assertEqualSQL(db, A.including(required: A.restrictedC2), """
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
                        .allColumns,
                        .rowID))
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
            #if compiler(>=6.1)
            do {
                let aAlias = TableAlias<A>()
                let request = A
                    .aliased(aAlias)
                    .including(required: A.c
                        .select { [
                            $0.name,
                            ($0.id + aAlias.id).forKey("foo")
                        ] })
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c"."name", "c"."id" + "a"."id" AS "foo" \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId"
                    """)
            }
            #endif
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
            do {
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
            #if compiler(>=6.1)
            do {
                let cAlias = TableAlias<C>()
                let request = A
                    .including(required: A.c.aliased(cAlias))
                    .filter { _ in cAlias.name != nil }
                try assertEqualSQL(db, request, """
                    SELECT "a".*, "c".* \
                    FROM "a" \
                    JOIN "b" ON "b"."id" = "a"."bId" \
                    JOIN "c" ON "c"."id" = "b"."cId" \
                    WHERE "c"."name" IS NOT NULL
                    """)
            }
            #endif
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
