import XCTest
import GRDB

class DatabaseSchemaSourceTests: GRDBTestCase {
    func test_schemaSource_can_query_schema() throws {
        struct SchemaSource: DatabaseSchemaSource {
            func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
                let tableName = view.name + "_table"
                if try db.tableExists(view.name + "_table"),
                   try db.primaryKey(tableName).columns == ["id"],
                   try db.columns(in: view.name, in: view.schemaID.name).contains(where: { $0.name == "name" })
                {
                    return ["id"]
                } else {
                    return nil
                }
            }
        }
        
        dbConfiguration.schemaSource = SchemaSource()
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            try db.execute(sql: """
                -- Matches SchemaSource
                CREATE TABLE view1_table(id INTEGER PRIMARY KEY, name TEXT);
                CREATE VIEW view1 AS SELECT * FROM view1_table;
                
                -- Does not match SchemaSource
                CREATE VIEW view2 AS SELECT 1;

                -- Does not match SchemaSource
                CREATE TABLE view3_table(uuid TEXT PRIMARY KEY);
                CREATE VIEW view3 AS SELECT * FROM view3_table;

                -- Does not match SchemaSource
                CREATE TABLE view4_table(id INTEGER PRIMARY KEY, name TEXT);
                CREATE VIEW view4 AS SELECT id FROM view4_table;
                """)
            
            try XCTAssertEqual(db.primaryKey("view1").columns, ["id"])
            XCTAssertThrowsError(try db.primaryKey("view2"))
            XCTAssertThrowsError(try db.primaryKey("view3"))
            XCTAssertThrowsError(try db.primaryKey("view4"))
        }
    }
    
    func test_then_with_columnsForPrimaryKey_inView() throws {
        struct SchemaSource1: DatabaseSchemaSource {
            func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
                switch view.name {
                case "view1": ["code"]
                case "view2": ["id"]
                default: nil
                }
            }
        }
        
        struct SchemaSource2: DatabaseSchemaSource {
            func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
                switch view.name {
                case "view1": ["identifier"]
                case "view3": ["uuid"]
                default: nil
                }
            }
        }
        
        func setupSchema(_ db: Database) throws {
            try db.execute(sql: """
                CREATE VIEW view1 AS SELECT 'foo' AS code, 'whatever' AS identifier;
                CREATE VIEW view2 AS SELECT 1 AS id;
                CREATE VIEW view3 AS SELECT 'foo' AS uuid;
                """)
        }
        
        do {
            let schemaSource = SchemaSource1().then(SchemaSource2())
            dbConfiguration.schemaSource = schemaSource
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try setupSchema(db)
                try XCTAssertEqual(db.primaryKey("view1").columns, ["code"])
                try XCTAssertEqual(db.primaryKey("view2").columns, ["id"])
                try XCTAssertEqual(db.primaryKey("view3").columns, ["uuid"])
            }
        }
        
        do {
            let schemaSource = SchemaSource2().then(SchemaSource1())
            dbConfiguration.schemaSource = schemaSource
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.write { db in
                try setupSchema(db)
                try XCTAssertEqual(db.primaryKey("view1").columns, ["identifier"])
                try XCTAssertEqual(db.primaryKey("view2").columns, ["id"])
                try XCTAssertEqual(db.primaryKey("view3").columns, ["uuid"])
            }
        }
    }
}
