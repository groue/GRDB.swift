import XCTest
import GRDB

/// Test SQL generation
class AssociationBelongsToSQLTests: GRDBTestCase {
    
    func testSingleColumnNoForeignKeyNoPrimaryKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentID: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentId"] = parentID
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer)
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."rowid" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."rowid" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."rowid" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."rowid" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."rowid" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "rowid" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."rowid" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testSingleColumnNoForeignKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentID: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentId"] = parentID
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testSingleColumnSingleForeignKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentID: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentId"] = parentID
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer).references("parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self),
                Child.belongsTo(Table(Parent.databaseTableName)),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentId")], to: [Column("id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parentId") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testSingleColumnSeveralForeignKeys() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parent1ID: Int?
            var parent2ID: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parent1Id"] = parent1ID
                container["parent2Id"] = parent2ID
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parent1Id", .integer).references("parents")
                t.column("parent2Id", .integer).references("parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent1Id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent1Id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parent1Id") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent1Id")], to: [Column("id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent1Id")], to: [Column("id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent1Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parent1Id") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent2Id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent2Id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parent2Id") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 2
                    """)
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 2
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent2Id")], to: [Column("id")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent2Id")], to: [Column("id")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON "parents"."id" = "children"."parent2Id"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."id" = "children"."parent2Id") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE "id" = 2
                    """)
                try assertEqualSQL(db, Child(parent1ID: 1, parent2ID: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE "custom"."id" = 2
                    """)
                
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1ID: nil, parent2ID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testCompoundColumnNoForeignKeyNoPrimaryKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentA: Int?
            var parentB: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentA"] = parentA
                container["parentB"] = parentB
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testCompoundColumnNoForeignKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentA: Int?
            var parentB: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentA"] = parentA
                container["parentB"] = parentB
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("name", .text)
                t.primaryKey(["a", "b"])
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentA"), Column("parentB")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentA"), Column("parentB")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testCompoundColumnSingleForeignKey() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parentA: Int?
            var parentB: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parentA"] = parentA
                container["parentB"] = parentB
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("name", .text)
                t.primaryKey(["a", "b"])
            }
            try db.create(table: "children") { t in
                t.column("parentA", .integer)
                t.column("parentB", .integer)
                t.foreignKey(["parentA", "parentB"], references: "parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self),
                Child.belongsTo(Table(Parent.databaseTableName)),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 2, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentA"), Column("parentB")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentA"), Column("parentB")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parentA"), Column("parentB")], to: [Column("a"), Column("b")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parentA") AND ("parents"."b" = "children"."parentB") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: 1, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: 2).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentA: nil, parentB: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
        }
    }
    
    func testCompoundColumnSeveralForeignKeys() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "children"
            var parent1A: Int?
            var parent1B: Int?
            var parent2A: Int?
            var parent2B: Int?
            func encode(to container: inout PersistenceContainer) {
                container["parent1A"] = parent1A
                container["parent1B"] = parent1B
                container["parent2A"] = parent2A
                container["parent2B"] = parent2B
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("a", .integer)
                t.column("b", .integer)
                t.column("name", .text)
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
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent1A"), Column("parent1B")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent1A"), Column("parent1B")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent1A"), Column("parent1B")], to: [Column("a"), Column("b")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent1A"), Column("parent1B")], to: [Column("a"), Column("b")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent1A") AND ("parents"."b" = "children"."parent1B") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 1) AND ("b" = 2)
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 1) AND ("custom"."b" = 2)
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: nil, parent1B: nil, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent2A"), Column("parent2B")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent2A"), Column("parent2B")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 3) AND ("b" = 4)
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 3) AND ("custom"."b" = 4)
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("parent2A"), Column("parent2B")], to: [Column("a"), Column("b")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("parent2A"), Column("parent2B")], to: [Column("a"), Column("b")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "children".*, "parents".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "children".* \
                    FROM "children" \
                    JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B")
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "children".* \
                    FROM "children" \
                    LEFT JOIN "parents" ON ("parents"."a" = "children"."parent2A") AND ("parents"."b" = "children"."parent2B") AND ("parents"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE ("a" = 3) AND ("b" = 4)
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE ("custom"."a" = 3) AND ("custom"."b" = 4)
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: 3, parent2B: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
                
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: 4).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: 4).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)

                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: nil).request(for: association), """
                    SELECT * FROM "parents" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parent1A: 1, parent1B: 2, parent2A: nil, parent2B: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "parents" "custom" WHERE 0
                    """)
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
            static let parent1 = belongsTo(Parent.self, using: ForeignKeys.parent1)
            static let parent2 = belongsTo(Parent.self, using: ForeignKeys.parent2)
        }
    }
    
    // Regression test for https://github.com/groue/GRDB.swift/issues/495
    func testFetchCount() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("aId", .integer).references("a")
            }
            struct A: TableRecord { }
            struct B: TableRecord { }
            let request = B.joining(required: B.belongsTo(A.self))
            let _ = try request.fetchCount(db)
        }
    }
    
    func testCaseInsensitivity() throws {
        struct Child : TableRecord, EncodableRecord {
            static let databaseTableName = "CHILDREN"
            var parentID: Int?
            func encode(to container: inout PersistenceContainer) {
                container["PaReNtId"] = parentID
            }
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "PARENTS"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.column("id", .integer).primaryKey()
                t.column("name", .text)
            }
            try db.create(table: "children") { t in
                t.column("parentId", .integer).references("parents")
            }
        }
        
        try dbQueue.inDatabase { db in
            for association in [
                Child.belongsTo(Parent.self),
                Child.belongsTo(Table(Parent.databaseTableName)),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON ("PARENTS"."id" = "CHILDREN"."parentId") AND ("PARENTS"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("PARENTID")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("PARENTID")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."id" = "CHILDREN"."parentId"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON ("PARENTS"."id" = "CHILDREN"."parentId") AND ("PARENTS"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE "id" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE "custom"."id" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE 0
                    """)
            }
            
            for association in [
                Child.belongsTo(Parent.self,
                                using: ForeignKey([Column("PARENTID")], to: [Column("ID")])),
                Child.belongsTo(Table(Parent.databaseTableName),
                                using: ForeignKey([Column("PARENTID")], to: [Column("ID")])),
            ] {
                try assertEqualSQL(db, Child.including(required: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."ID" = "CHILDREN"."PARENTID"
                    """)
                try assertEqualSQL(db, Child.including(optional: association), """
                    SELECT "CHILDREN".*, "PARENTS".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."ID" = "CHILDREN"."PARENTID"
                    """)
                try assertEqualSQL(db, Child.joining(required: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    JOIN "PARENTS" ON "PARENTS"."ID" = "CHILDREN"."PARENTID"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON "PARENTS"."ID" = "CHILDREN"."PARENTID"
                    """)
                try assertEqualSQL(db, Child.joining(optional: association.filter(Column("name") == "foo")), """
                    SELECT "CHILDREN".* \
                    FROM "CHILDREN" \
                    LEFT JOIN "PARENTS" ON ("PARENTS"."ID" = "CHILDREN"."PARENTID") AND ("PARENTS"."name" = 'foo')
                    """)
                
                try assertEqualSQL(db, Child(parentID: 1).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE "ID" = 1
                    """)
                try assertEqualSQL(db, Child(parentID: 1).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE "custom"."ID" = 1
                    """)
                
                try assertEqualSQL(db, Child(parentID: nil).request(for: association), """
                    SELECT * FROM "PARENTS" WHERE 0
                    """)
                try assertEqualSQL(db, Child(parentID: nil).request(for: association).aliased(TableAlias(name: "custom")), """
                    SELECT "custom".* FROM "PARENTS" "custom" WHERE 0
                    """)
            }
        }
    }
    
    // Test for the "How do I filter records and only keep those that are
    // associated to another record?" FAQ
    func testRecordsFilteredByExistingAssociatedRecord() throws {
        struct Book: TableRecord {
            static let author = belongsTo(Author.self)
        }
        
        struct Author: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "author") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "book") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("authorID", .integer).references("author")
            }
            
            let request = Book.joining(required: Book.author)
            try assertEqualSQL(db, request, """
                SELECT "book".* FROM "book" \
                JOIN "author" ON "author"."id" = "book"."authorID"
                """)
        }
    }
    
    // Test for the "How do I filter records and only keep those that are NOT
    // associated to another record?" FAQ
    func testRecordsFilteredByNonExistingAssociatedRecord() throws {
        struct Book: TableRecord {
            static let author = belongsTo(Author.self)
        }
        
        struct Author: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "author") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "book") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("authorID", .integer).references("author")
            }
            
            let authorAlias = TableAlias()
            let request = Book
                .joining(optional: Book.author.aliased(authorAlias))
                .filter(!authorAlias.exists)
            try assertEqualSQL(db, request, """
                SELECT "book".* FROM "book" \
                LEFT JOIN "author" ON "author"."id" = "book"."authorID" \
                WHERE "author"."id" IS NULL
                """)
        }
    }
}
