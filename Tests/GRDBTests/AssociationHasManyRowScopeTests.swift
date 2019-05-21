import XCTest
#if GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

class AssociationHasManyRowScopeTests: GRDBTestCase {

    func testSingularTable() throws {
        struct Child : TableRecord {
        }
        
        struct Parent : TableRecord {
            static let children = hasMany(Child.self)
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
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO child (id, parentId) VALUES (2, 1);
                """)
            
            let request = Parent.including(required: Parent.children)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(row.scopes["child"], ["id": 2, "parentId": 1])
        }
    }
    
    func testPluralTable() throws {
        struct Child : TableRecord {
            static let databaseTableName = "children"
        }
        
        struct Parent : TableRecord {
            static let databaseTableName = "parents"
            static let children = hasMany(Child.self)
        }
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parents") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            try db.create(table: "children") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("parentId", .integer).references("parents")
            }
            try db.execute(sql: """
                INSERT INTO parents (id) VALUES (1);
                INSERT INTO children (id, parentId) VALUES (2, 1);
                """)
            
            let request = Parent.including(required: Parent.children)
            let row = try Row.fetchOne(db, request)!
            XCTAssertEqual(row.unscoped, ["id": 1])
            XCTAssertEqual(row.scopes["child"], ["id": 2, "parentId": 1])
        }
    }
    
    func testCustomKey() throws {
        struct Child : TableRecord {
        }
        
        struct Parent : TableRecord {
            static let littlePuppies = hasMany(Child.self, key: "littlePuppies")
            static let kittens = hasMany(Child.self).forKey("kittens")
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
            try db.execute(sql: """
                INSERT INTO parent (id) VALUES (1);
                INSERT INTO child (id, parentId) VALUES (2, 1);
                """)
            
            do {
                let request = Parent.including(required: Parent.littlePuppies)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(row.scopes["littlePuppy"], ["id": 2, "parentId": 1])
            }
            do {
                let request = Parent.including(required: Parent.kittens)
                let row = try Row.fetchOne(db, request)!
                XCTAssertEqual(row.unscoped, ["id": 1])
                XCTAssertEqual(row.scopes["kitten"], ["id": 2, "parentId": 1])
            }
        }
    }
}
