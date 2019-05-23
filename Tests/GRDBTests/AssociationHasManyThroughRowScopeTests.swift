import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

/// Test SQL generation

class AssociationHasManyThroughRowScopeTests: GRDBTestCase {
    
    func testBelongsToHasManySingularTable() throws {
        struct Parent: TableRecord {
            static let child = belongsTo(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: child, using: Child.grandChildren)
        }
        struct Child: TableRecord {
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("child")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("child")
            }
            try db.execute(sql: """
                INSERT INTO child (id) VALUES (1);
                INSERT INTO parent (id, childId) VALUES (2, 1);
                INSERT INTO grandChild (id, childId) VALUES (3, 1);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 3, "childId": 1])
        }
    }
    
    func testBelongsToHasManyPluralTable() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let child = belongsTo(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: child, using: Child.grandChildren)
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("children")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("children")
            }
            try db.execute(sql: """
                INSERT INTO children (id) VALUES (1);
                INSERT INTO parents (id, childId) VALUES (2, 1);
                INSERT INTO grandChildren (id, childId) VALUES (3, 1);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 3, "childId": 1])
        }
    }
    
    func testBelongsToHasManyCustomKey() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let child = belongsTo(Child.self)
            static let littlePuppies = hasMany(GrandChild.self, through: child, using: Child.grandChildren, key: "littlePuppies")
            static let kittens = hasMany(GrandChild.self, through: child, using: Child.grandChildren).forKey("kittens")
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChildren = hasMany(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("children")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("childId").references("children")
            }
            try db.execute(sql: """
                INSERT INTO children (id) VALUES (1);
                INSERT INTO parents (id, childId) VALUES (2, 1);
                INSERT INTO grandChildren (id, childId) VALUES (3, 1);
                """)
            
            do {
                let request = Parent.including(required: Parent.littlePuppies)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["littlePuppy"], ["id": 3, "childId": 1])
            }
            
            do {
                let request = Parent.including(required: Parent.kittens)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 2, "childId": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["kitten"], ["id": 3, "childId": 1])
            }
        }
    }
    
    func testHasManyBelongsToSingularTable() throws {
        struct Parent: TableRecord {
            static let children = hasMany(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: children, using: Child.grandChild)
        }
        struct Child: TableRecord {
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId").references("parent")
                t.column("grandChildId").references("grandChild")
            }
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO grandChild (id) VALUES (2);
                INSERT INTO child (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 2])
        }
    }
    
    func testHasManyBelongsToPluralTable() throws {
        struct Parent: TableRecord {
            static let databaseTableName = "parents"
            static let children = hasMany(Child.self)
            static let grandChildren = hasMany(GrandChild.self, through: children, using: Child.grandChild)
        }
        struct Child: TableRecord {
            static let databaseTableName = "children"
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
            static let databaseTableName = "grandChildren"
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChildren") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId").references("parents")
                t.column("grandChildId").references("grandChildren")
            }
            try db.execute(sql: """
                INSERT INTO parents (id) VALUES (1);
                INSERT INTO grandChildren (id) VALUES (2);
                INSERT INTO children (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            let request = Parent.including(required: Parent.grandChildren)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(Set(row.scopes.names), ["child"])
            XCTAssertEqual(row.scopesTree["grandChild"], ["id": 2])
        }
    }
    
    func testHasManyBelongsToCustomKey() throws {
        struct Parent: TableRecord {
            static let children = hasMany(Child.self)
            static let littlePuppies = hasMany(GrandChild.self, through: children, using: Child.grandChild, key: "littlePuppies")
            static let kittens = hasMany(GrandChild.self, through: children, using: Child.grandChild).forKey("kittens")
        }
        struct Child: TableRecord {
            static let grandChild = belongsTo(GrandChild.self)
        }
        struct GrandChild: TableRecord {
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "parent") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "grandChild") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "child") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId").references("parent")
                t.column("grandChildId").references("grandChild")
            }
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO grandChild (id) VALUES (2);
                INSERT INTO child (id, parentId, grandChildId) VALUES (3, 1, 2);
                """)
            
            do {
                let request = Parent.including(required: Parent.littlePuppies)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["littlePuppy"], ["id": 2])
            }
            
            do {
                let request = Parent.including(required: Parent.kittens)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(Set(row.scopes.names), ["child"])
                XCTAssertEqual(row.scopesTree["kitten"], ["id": 2])
            }
        }
    }
}
