import XCTest
import GRDB

/// Test SQL generation
class AssociationHasManyFirstSQLTests: GRDBTestCase {
    func testHasManyFirst() throws {
        struct Child: TableRecord { }
        struct Parent: TableRecord, EncodableRecord {
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
                container["rowid"] = 2
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
            
            do {
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .first
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT * FROM "child" \
                    WHERE "parentId" = 1 \
                    ORDER BY "id" \
                    LIMIT 1
                    """)
            }
        }
    }
    
    func testHasManyFirstWithDeeperAssociation() throws {
        struct Toy: TableRecord { }
        struct Child: TableRecord { }
        struct Parent: TableRecord, EncodableRecord {
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
                container["rowid"] = 2
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
                t.autoIncrementedPrimaryKey("id")
                t.column("childId", .integer).references("child")
            }

            do {
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .first
                    .joining(required: Child.hasOne(Toy.self))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "child".* \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = 1 \
                    ORDER BY "child"."id" \
                    LIMIT 1
                    """)
            }
            
            do {
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .first
                    .including(required: Child.hasOne(Toy.self))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "child".*, "toy".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" LIMIT 1) \
                    JOIN "toy" ON "toy"."childId" = "child"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".*, "toy".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" LIMIT 1) \
                    JOIN "toy" ON "toy"."childId" = "child"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT "child".*, "toy".* \
                    FROM "child" \
                    JOIN "toy" \
                    ON "toy"."childId" = "child"."id" \
                    WHERE "child"."parentId" = 1 \
                    ORDER BY "child"."id" \
                    LIMIT 1
                    """)
            }
            
            do {
                let alias = TableAlias()
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .filter(Column("id") == alias[Column("id")] + 1)
                    .first
                    .joining(required: Child.hasOne(Toy.self).filter(Column("id") == alias[Column("id")] * 2))
                try assertEqualSQL(db, Parent.all().aliased(alias).including(required: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    JOIN "child" \
                    ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2)) \
                    WHERE ("child"."parentId" = "parent"."id") AND ("child"."id" = ("parent"."id" + 1)) \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().aliased(alias).joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" \
                    ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2)) \
                    WHERE ("child"."parentId" = "parent"."id") AND ("child"."id" = ("parent"."id" + 1)) \
                    ORDER BY "child"."id" \
                    LIMIT 1)
                    """)
            }

            do {
                let alias = TableAlias()
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .filter(Column("id") == alias[Column("id")] + 1)
                    .first
                    .including(required: Child.hasOne(Toy.self).filter(Column("id") == alias[Column("id")] * 2))
                try assertEqualSQL(db, Parent.all().aliased(alias).including(required: association), """
                    SELECT "parent".*, "child".*, "toy".* \
                    FROM "parent" \
                    JOIN "child" \
                    ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2)) \
                    WHERE ("child"."parentId" = "parent"."id") AND ("child"."id" = ("parent"."id" + 1)) \
                    ORDER BY "child"."id" \
                    LIMIT 1) \
                    JOIN "toy" \
                    ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2))
                    """)
                try assertEqualSQL(db, Parent.all().aliased(alias).joining(required: association), """
                    SELECT "parent".*, "toy".* \
                    FROM "parent" \
                    JOIN "child" \
                    ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    JOIN "toy" ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2)) \
                    WHERE ("child"."parentId" = "parent"."id") AND ("child"."id" = ("parent"."id" + 1)) \
                    ORDER BY "child"."id" \
                    LIMIT 1) \
                    JOIN "toy" \
                    ON ("toy"."childId" = "child"."id") AND ("toy"."id" = ("parent"."id" * 2))
                    """)
            }
        }
    }

    func testHasManyLast() throws {
        struct Child: TableRecord { }
        struct Parent: TableRecord, EncodableRecord {
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
                container["rowid"] = 2
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
            
            do {
                let association = Parent
                    .hasMany(Child.self)
                    .orderByPrimaryKey()
                    .last
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" DESC \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parent".*, "child".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" DESC \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" DESC \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parent".* \
                    FROM "parent" \
                    LEFT JOIN "child" ON "child"."id" = (\
                    SELECT "child"."id" \
                    FROM "child" \
                    WHERE "child"."parentId" = "parent"."id" \
                    ORDER BY "child"."id" DESC \
                    LIMIT 1)
                    """)
                try assertEqualSQL(db, Parent().request(for: association), """
                    SELECT * FROM "child" \
                    WHERE "parentId" = 1 \
                    ORDER BY "id" DESC \
                    LIMIT 1
                    """)
            }
        }
    }
}
