import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test SQL generation
class AssociationHasOneSQLTests: GRDBTestCase {

    func testSingleColumnNoForeignKeyNoPrimaryKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
                container["rowid"] = 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer)
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."rowid"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."rowid"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 2")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")], to: [Column("id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
        }
    }
    
    func testSingleColumnNoForeignKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")], to: [Column("id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
        }
    }
    
    func testSingleColumnSingleForeignKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer).references("parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self)
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentId")], to: [Column("id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parentId" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parentId\" = 1")
            }
        }
    }
    
    func testSingleColumnSeveralForeignKeys() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["id"] = 1
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
            }
            try db.create(table: "children") { t in
                t.column("parent1Id", .integer).references("parents")
                t.column("parent2Id", .integer).references("parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent1Id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parent1Id\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent1Id")], to: [Column("id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent1Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parent1Id\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent2Id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parent2Id\" = 1")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent2Id")], to: [Column("id")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON "children"."parent2Id" = "parents"."id"
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE \"parent2Id\" = 1")
            }
        }
    }
    
    func testCompoundColumnNoForeignKeyNoPrimaryKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["a"] = 1
                container["b"] = 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
        }
    }
    
    func testCompoundColumnNoForeignKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["a"] = 1
                container["b"] = 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.primaryKey(["a", "b"])
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentA"), Column("parentB")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
        }
    }
    
    func testCompoundColumnSingleForeignKey() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["a"] = 1
                container["b"] = 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.primaryKey(["a", "b"])
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
                t.foreignKey(["parentA", "parentB"], references: "parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self)
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentA"), Column("parentB")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parentA" = "parents"."a") AND ("children"."parentB" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parentA\" = 1) AND (\"parentB\" = 2)")
            }
        }
    }
    
    func testCompoundColumnSeveralForeignKeys() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord, EncodableRecord {
            static let databaseTableName = "parents"
            func encode(to container: inout PersistenceContainer) {
                container["a"] = 1
                container["b"] = 2
            }
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.primaryKey(["a", "b"])
            }
            try db.create(table: "children") { t in
                t.column("parent1A", .integer)
                t.column("parent1B", .integer)
                t.column("parent2A", .integer)
                t.column("parent2B", .integer)
                t.foreignKey(["parent1A", "parent1B"], references: "parents")
                t.foreignKey(["parent2A", "parent2B"], references: "parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent1A"), Column("parent1B")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parent1A\" = 1) AND (\"parent1B\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent1A"), Column("parent1B")], to: [Column("a"), Column("b")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent1A" = "parents"."a") AND ("children"."parent1B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parent1A\" = 1) AND (\"parent1B\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent2A"), Column("parent2B")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parent2A\" = 1) AND (\"parent2B\" = 2)")
            }
            do {
                let association = Parent.hasOne(Child.self, using: ForeignKey([Column("parent2A"), Column("parent2B")], to: [Column("a"), Column("b")]))
                try assertEqualSQL(db, Parent.all().including(required: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().including(optional: association), """
                    SELECT "parents".*, "children".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(required: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent.all().joining(optional: association), """
                    SELECT "parents".* \
                    FROM "parents" \
                    LEFT JOIN "children" ON ("children"."parent2A" = "parents"."a") AND ("children"."parent2B" = "parents"."b")
                    """)
                try assertEqualSQL(db, Parent().request(for: association), "SELECT * FROM \"children\" WHERE (\"parent2A\" = 1) AND (\"parent2B\" = 2)")
            }
        }
    }
    
    func testForeignKeyDefinitionFromColumn() {
        // This test pass if code compiles
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
            enum Columns {
                static let id = Column("id")
            }
            static let child1 = hasOne(Child.self, using: Child.ForeignKeys.parent1)
            static let child2 = hasOne(Child.self, using: Child.ForeignKeys.parent2)
        }
        
        struct Child : TableRecord {
            static let databaseTableName = "children"
            enum Columns {
                static let parentId = Column("parentId")
            }
            enum ForeignKeys {
                static let parent1 = ForeignKey([Columns.parentId])
                static let parent2 = ForeignKey([Columns.parentId], to: [Parent.Columns.id])
            }
        }
    }
}
