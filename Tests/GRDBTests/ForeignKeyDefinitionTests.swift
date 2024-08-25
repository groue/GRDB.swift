import XCTest
@testable import GRDB

class ForeignKeyDefinitionTests: GRDBTestCase {
    func testTable_belongsTo_hiddenRowID_plain() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                // Custom names
                t.belongsTo("customParent", inTable: "parent")
                t.belongsTo("customCountry", inTable: "country")
                t.belongsTo("customTeam", inTable: "teams")
                t.belongsTo("customPerson", inTable: "people")
                t.column("b")
            }
            
            XCTAssertEqual(sqlQueries.suffix(9), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentId" INTEGER REFERENCES "parent"("rowid"), \
                "COUNTRYId" INTEGER REFERENCES "COUNTRY"("rowid"), \
                "teamId" INTEGER REFERENCES "teams"("rowid"), \
                "peopleId" INTEGER REFERENCES "people"("rowid"), \
                "customParentId" INTEGER REFERENCES "parent"("rowid"), \
                "customCountryId" INTEGER REFERENCES "country"("rowid"), \
                "customTeamId" INTEGER REFERENCES "teams"("rowid"), \
                "customPersonId" INTEGER REFERENCES "people"("rowid"), \
                "b"\
                )
                """,
                """
                CREATE INDEX "child_on_parentId" ON "child"("parentId")
                """,
                """
                CREATE INDEX "child_on_COUNTRYId" ON "child"("COUNTRYId")
                """,
                """
                CREATE INDEX "child_on_teamId" ON "child"("teamId")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
                """
                CREATE INDEX "child_on_customParentId" ON "child"("customParentId")
                """,
                """
                CREATE INDEX "child_on_customCountryId" ON "child"("customCountryId")
                """,
                """
                CREATE INDEX "child_on_customTeamId" ON "child"("customTeamId")
                """,
                """
                CREATE INDEX "child_on_customPersonId" ON "child"("customPersonId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_hiddenRowID_ifNotExists() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child", options: .ifNotExists) { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                t.column("b")
            }
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE IF NOT EXISTS "child" (\
                "a", \
                "parentId" INTEGER REFERENCES "parent"("rowid"), \
                "COUNTRYId" INTEGER REFERENCES "COUNTRY"("rowid"), \
                "teamId" INTEGER REFERENCES "teams"("rowid"), \
                "peopleId" INTEGER REFERENCES "people"("rowid"), \
                "b")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_parentId" ON "child"("parentId")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_COUNTRYId" ON "child"("COUNTRYId")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_teamId" ON "child"("teamId")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_hiddenRowID_unique() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").unique()
                // Modified case of table name
                t.belongsTo("COUNTRY").unique()
                // Singularized table name
                t.belongsTo("team").unique()
                // Raw plural table name
                t.belongsTo("people").unique()
                t.column("b")
            }
            XCTAssertEqual(lastSQLQuery, """
                CREATE TABLE "child" (\
                "a", \
                "parentId" INTEGER UNIQUE REFERENCES "parent"("rowid"), \
                "COUNTRYId" INTEGER UNIQUE REFERENCES "COUNTRY"("rowid"), \
                "teamId" INTEGER UNIQUE REFERENCES "teams"("rowid"), \
                "peopleId" INTEGER UNIQUE REFERENCES "people"("rowid"), \
                "b")
                """)
        }
    }
    
    func testTable_belongsTo_hiddenRowID_notIndexed() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", indexed: false)
                // Modified case of table name
                t.belongsTo("COUNTRY", indexed: false)
                // Singularized table name
                t.belongsTo("team", indexed: false)
                // Raw plural table name
                t.belongsTo("people", indexed: false)
                t.column("b")
            }
            XCTAssertEqual(lastSQLQuery, """
                CREATE TABLE "child" (\
                "a", \
                "parentId" INTEGER REFERENCES "parent"("rowid"), \
                "COUNTRYId" INTEGER REFERENCES "COUNTRY"("rowid"), \
                "teamId" INTEGER REFERENCES "teams"("rowid"), \
                "peopleId" INTEGER REFERENCES "people"("rowid"), \
                "b")
                """)
        }
    }
    
    func testTable_belongsTo_hiddenRowID_notNull() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").notNull()
                // Modified case of table name
                t.belongsTo("COUNTRY").notNull()
                // Singularized table name
                t.belongsTo("team").notNull()
                // Raw plural table name
                t.belongsTo("people").notNull()
                t.column("b")
            }
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentId" INTEGER NOT NULL REFERENCES "parent"("rowid"), \
                "COUNTRYId" INTEGER NOT NULL REFERENCES "COUNTRY"("rowid"), \
                "teamId" INTEGER NOT NULL REFERENCES "teams"("rowid"), \
                "peopleId" INTEGER NOT NULL REFERENCES "people"("rowid"), \
                "b")
                """,
                """
                CREATE INDEX "child_on_parentId" ON "child"("parentId")
                """,
                """
                CREATE INDEX "child_on_COUNTRYId" ON "child"("COUNTRYId")
                """,
                """
                CREATE INDEX "child_on_teamId" ON "child"("teamId")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_hiddenRowID_foreignKeyOptions() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "country") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "teams") { t in
                t.column("name", .text)
            }
            
            try db.create(table: "people") { t in
                t.column("name", .text)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Modified case of table name
                t.belongsTo("COUNTRY", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Singularized table name
                t.belongsTo("team", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Raw plural table name
                t.belongsTo("people", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                t.column("b")
            }
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentId" INTEGER REFERENCES "parent"("rowid") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "COUNTRYId" INTEGER REFERENCES "COUNTRY"("rowid") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "teamId" INTEGER REFERENCES "teams"("rowid") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "peopleId" INTEGER REFERENCES "people"("rowid") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "b")
                """,
                """
                CREATE INDEX "child_on_parentId" ON "child"("parentId")
                """,
                """
                CREATE INDEX "child_on_COUNTRYId" ON "child"("COUNTRYId")
                """,
                """
                CREATE INDEX "child_on_teamId" ON "child"("teamId")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_hiddenRowID_autoreference_singular() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "employee") { t in
                t.column("a")
                t.belongsTo("employee")
                t.belongsTo("custom", inTable: "employee")
                t.column("b")
            }
            
            XCTAssertEqual(sqlQueries.suffix(3), [
                """
                CREATE TABLE "employee" (\
                "a", \
                "employeeId" INTEGER REFERENCES "employee"("rowid"), \
                "customId" INTEGER REFERENCES "employee"("rowid"), \
                "b"\
                )
                """,
                """
                CREATE INDEX "employee_on_employeeId" ON "employee"("employeeId")
                """,
                """
                CREATE INDEX "employee_on_customId" ON "employee"("customId")
                """
            ])
        }
    }
    
    func testTable_belongsTo_hiddenRowID_autoreference_plural() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "employees") { t in
                t.column("a")
                t.belongsTo("employee")
                t.belongsTo("custom", inTable: "employees")
                t.column("b")
            }
            
            XCTAssertEqual(sqlQueries.suffix(3), [
                """
                CREATE TABLE "employees" (\
                "a", \
                "employeeId" INTEGER REFERENCES "employees"("rowid"), \
                "customId" INTEGER REFERENCES "employees"("rowid"), \
                "b"\
                )
                """,
                """
                CREATE INDEX "employees_on_employeeId" ON "employees"("employeeId")
                """,
                """
                CREATE INDEX "employees_on_customId" ON "employees"("customId")
                """
            ])
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_plain() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                // Custom names
                t.belongsTo("customParent", inTable: "parent")
                t.belongsTo("customCountry", inTable: "country")
                t.belongsTo("customTeam", inTable: "teams")
                t.belongsTo("customPerson", inTable: "people")
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(9), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentPrimaryKey" TEXT REFERENCES "parent"("primaryKey"), \
                "COUNTRYCode" CUSTOM TYPE REFERENCES "COUNTRY"("code"), \
                "teamPrimaryKey" INTEGER REFERENCES "teams"("primaryKey"), \
                "peopleId" INTEGER REFERENCES "people"("id"), \
                "customParentPrimaryKey" TEXT REFERENCES "parent"("primaryKey"), \
                "customCountryCode" CUSTOM TYPE REFERENCES "country"("code"), \
                "customTeamPrimaryKey" INTEGER REFERENCES "teams"("primaryKey"), \
                "customPersonId" INTEGER REFERENCES "people"("id"), \
                "e"\
                )
                """,
                """
                CREATE INDEX "child_on_parentPrimaryKey" ON "child"("parentPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_COUNTRYCode" ON "child"("COUNTRYCode")
                """,
                """
                CREATE INDEX "child_on_teamPrimaryKey" ON "child"("teamPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
                """
                CREATE INDEX "child_on_customParentPrimaryKey" ON "child"("customParentPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_customCountryCode" ON "child"("customCountryCode")
                """,
                """
                CREATE INDEX "child_on_customTeamPrimaryKey" ON "child"("customTeamPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_customPersonId" ON "child"("customPersonId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_ifNotExists() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child", options: .ifNotExists) { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE IF NOT EXISTS "child" (\
                "a", \
                "parentPrimaryKey" TEXT REFERENCES "parent"("primaryKey"), \
                "COUNTRYCode" CUSTOM TYPE REFERENCES "COUNTRY"("code"), \
                "teamPrimaryKey" INTEGER REFERENCES "teams"("primaryKey"), \
                "peopleId" INTEGER REFERENCES "people"("id"), \
                "e"\
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_parentPrimaryKey" ON "child"("parentPrimaryKey")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_COUNTRYCode" ON "child"("COUNTRYCode")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_teamPrimaryKey" ON "child"("teamPrimaryKey")
                """,
                """
                CREATE INDEX IF NOT EXISTS "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_unique() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").unique()
                // Modified case of table name
                t.belongsTo("COUNTRY").unique()
                // Singularized table name
                t.belongsTo("team").unique()
                // Raw plural table name
                t.belongsTo("people").unique()
                t.column("e")
            }
            
            XCTAssertEqual(lastSQLQuery, """
                CREATE TABLE "child" (\
                "a", \
                "parentPrimaryKey" TEXT UNIQUE REFERENCES "parent"("primaryKey"), \
                "COUNTRYCode" CUSTOM TYPE UNIQUE REFERENCES "COUNTRY"("code"), \
                "teamPrimaryKey" INTEGER UNIQUE REFERENCES "teams"("primaryKey"), \
                "peopleId" INTEGER UNIQUE REFERENCES "people"("id"), \
                "e"\
                )
                """)
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_notIndexed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", indexed: false)
                // Modified case of table name
                t.belongsTo("COUNTRY", indexed: false)
                // Singularized table name
                t.belongsTo("team", indexed: false)
                // Raw plural table name
                t.belongsTo("people", indexed: false)
                t.column("e")
            }
            
            XCTAssertEqual(lastSQLQuery, """
                CREATE TABLE "child" (\
                "a", \
                "parentPrimaryKey" TEXT REFERENCES "parent"("primaryKey"), \
                "COUNTRYCode" CUSTOM TYPE REFERENCES "COUNTRY"("code"), \
                "teamPrimaryKey" INTEGER REFERENCES "teams"("primaryKey"), \
                "peopleId" INTEGER REFERENCES "people"("id"), \
                "e"\
                )
                """)
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_notNull() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").notNull()
                // Modified case of table name
                t.belongsTo("COUNTRY").notNull()
                // Singularized table name
                t.belongsTo("team").notNull()
                // Raw plural table name
                t.belongsTo("people").notNull()
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentPrimaryKey" TEXT NOT NULL REFERENCES "parent"("primaryKey"), \
                "COUNTRYCode" CUSTOM TYPE NOT NULL REFERENCES "COUNTRY"("code"), \
                "teamPrimaryKey" INTEGER NOT NULL REFERENCES "teams"("primaryKey"), \
                "peopleId" INTEGER NOT NULL REFERENCES "people"("id"), \
                "e"\
                )
                """,
                """
                CREATE INDEX "child_on_parentPrimaryKey" ON "child"("parentPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_COUNTRYCode" ON "child"("COUNTRYCode")
                """,
                """
                CREATE INDEX "child_on_teamPrimaryKey" ON "child"("teamPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_foreignKeyOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.primaryKey("primaryKey", .text)
            }
            
            // Custom type
            try db.create(table: "country") { t in
                t.primaryKey("code", .init(rawValue: "CUSTOM TYPE"))
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey("primaryKey", .integer)
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey("id", .integer)
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Modified case of table name
                t.belongsTo("COUNTRY", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Singularized table name
                t.belongsTo("team", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Raw plural table name
                t.belongsTo("people", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentPrimaryKey" TEXT REFERENCES "parent"("primaryKey") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "COUNTRYCode" CUSTOM TYPE REFERENCES "COUNTRY"("code") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "teamPrimaryKey" INTEGER REFERENCES "teams"("primaryKey") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "peopleId" INTEGER REFERENCES "people"("id") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                "e"\
                )
                """,
                """
                CREATE INDEX "child_on_parentPrimaryKey" ON "child"("parentPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_COUNTRYCode" ON "child"("COUNTRYCode")
                """,
                """
                CREATE INDEX "child_on_teamPrimaryKey" ON "child"("teamPrimaryKey")
                """,
                """
                CREATE INDEX "child_on_peopleId" ON "child"("peopleId")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_autoreference_singular() throws {
        try makeDatabaseQueue().inDatabase { db in
            do {
                clearSQLQueries()
                try db.create(table: "employee") { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("a")
                    t.belongsTo("employee")
                    t.belongsTo("custom", inTable: "employee")
                    t.column("b")
                }
                
                XCTAssertEqual(sqlQueries.suffix(3), [
                    """
                    CREATE TABLE "employee" (\
                    "id" INTEGER PRIMARY KEY AUTOINCREMENT, \
                    "a", \
                    "employeeId" INTEGER REFERENCES "employee"("id"), \
                    "customId" INTEGER REFERENCES "employee"("id"), \
                    "b"\
                    )
                    """,
                    """
                    CREATE INDEX "employee_on_employeeId" ON "employee"("employeeId")
                    """,
                    """
                    CREATE INDEX "employee_on_customId" ON "employee"("customId")
                    """
                ])
            }
            
            do {
                clearSQLQueries()
                try db.create(table: "node") { t in
                    t.primaryKey { t.column("code") }
                    t.column("a")
                    t.belongsTo("node")
                    t.belongsTo("custom", inTable: "node")
                    t.column("b")
                }
                
                XCTAssertEqual(sqlQueries.suffix(3), [
                    """
                    CREATE TABLE "node" (\
                    "code" NOT NULL, \
                    "a", \
                    "nodeCode" REFERENCES "node"("code"), \
                    "customCode" REFERENCES "node"("code"), \
                    "b", \
                    PRIMARY KEY ("code")\
                    )
                    """,
                    """
                    CREATE INDEX "node_on_nodeCode" ON "node"("nodeCode")
                    """,
                    """
                    CREATE INDEX "node_on_customCode" ON "node"("customCode")
                    """
                ])
            }
        }
    }
    
    func testTable_belongsTo_singleColumnPrimaryKey_autoreference_plural() throws {
        try makeDatabaseQueue().inDatabase { db in
            do {
                clearSQLQueries()
                try db.create(table: "employees") { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("a")
                    t.belongsTo("employee")
                    t.belongsTo("custom", inTable: "employees")
                    t.column("b")
                }
                
                XCTAssertEqual(sqlQueries.suffix(3), [
                    """
                    CREATE TABLE "employees" (\
                    "id" INTEGER PRIMARY KEY AUTOINCREMENT, \
                    "a", \
                    "employeeId" INTEGER REFERENCES "employees"("id"), \
                    "customId" INTEGER REFERENCES "employees"("id"), \
                    "b"\
                    )
                    """,
                    """
                    CREATE INDEX "employees_on_employeeId" ON "employees"("employeeId")
                    """,
                    """
                    CREATE INDEX "employees_on_customId" ON "employees"("customId")
                    """
                ])
            }
            
            do {
                clearSQLQueries()
                try db.create(table: "nodes") { t in
                    t.primaryKey { t.column("code") }
                    t.column("a")
                    t.belongsTo("node")
                    t.belongsTo("custom", inTable: "nodes")
                    t.column("b")
                }
                
                XCTAssertEqual(sqlQueries.suffix(3), [
                    """
                    CREATE TABLE "nodes" (\
                    "code" NOT NULL, \
                    "a", \
                    "nodeCode" REFERENCES "nodes"("code"), \
                    "customCode" REFERENCES "nodes"("code"), \
                    "b", \
                    PRIMARY KEY ("code")\
                    )
                    """,
                    """
                    CREATE INDEX "nodes_on_nodeCode" ON "nodes"("nodeCode")
                    """,
                    """
                    CREATE INDEX "nodes_on_customCode" ON "nodes"("customCode")
                    """
                ])
            }
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_plain() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                // Custom names
                t.belongsTo("customParent", inTable: "parent")
                t.belongsTo("customCountry", inTable: "country")
                t.belongsTo("customTeam", inTable: "teams")
                t.belongsTo("customPerson", inTable: "people")
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(9), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentA" TEXT, \
                "parentB" CUSTOM TYPE, \
                "parentC", \
                "COUNTRYLeft" TEXT, \
                "COUNTRYRight" INTEGER, \
                "teamTop" TEXT, \
                "teamBottom" INTEGER, \
                "peopleMin" TEXT, \
                "peopleMax" INTEGER, \
                "customParentA" TEXT, \
                "customParentB" CUSTOM TYPE, \
                "customParentC", \
                "customCountryLeft" TEXT, \
                "customCountryRight" INTEGER, \
                "customTeamTop" TEXT, \
                "customTeamBottom" INTEGER, \
                "customPersonMin" TEXT, \
                "customPersonMax" INTEGER, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right"), \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max"), \
                FOREIGN KEY ("customParentA", "customParentB", "customParentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("customCountryLeft", "customCountryRight") REFERENCES "country"("left", "right"), \
                FOREIGN KEY ("customTeamTop", "customTeamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("customPersonMin", "customPersonMax") REFERENCES "people"("min", "max")\
                )
                """,
                """
                CREATE INDEX "index_child_on_parentA_parentB_parentC" ON "child"("parentA", "parentB", "parentC")
                """,
                """
                CREATE INDEX "index_child_on_COUNTRYLeft_COUNTRYRight" ON "child"("COUNTRYLeft", "COUNTRYRight")
                """,
                """
                CREATE INDEX "index_child_on_teamTop_teamBottom" ON "child"("teamTop", "teamBottom")
                """,
                """
                CREATE INDEX "index_child_on_peopleMin_peopleMax" ON "child"("peopleMin", "peopleMax")
                """,
                """
                CREATE INDEX "index_child_on_customParentA_customParentB_customParentC" ON "child"("customParentA", "customParentB", "customParentC")
                """,
                """
                CREATE INDEX "index_child_on_customCountryLeft_customCountryRight" ON "child"("customCountryLeft", "customCountryRight")
                """,
                """
                CREATE INDEX "index_child_on_customTeamTop_customTeamBottom" ON "child"("customTeamTop", "customTeamBottom")
                """,
                """
                CREATE INDEX "index_child_on_customPersonMin_customPersonMax" ON "child"("customPersonMin", "customPersonMax")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_ifNotExists() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child", options: .ifNotExists) { t in
                t.column("a")
                t.belongsTo("parent")
                // Modified case of table name
                t.belongsTo("COUNTRY")
                // Singularized table name
                t.belongsTo("team")
                // Raw plural table name
                t.belongsTo("people")
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE IF NOT EXISTS "child" (\
                "a", \
                "parentA" TEXT, \
                "parentB" CUSTOM TYPE, \
                "parentC", \
                "COUNTRYLeft" TEXT, \
                "COUNTRYRight" INTEGER, \
                "teamTop" TEXT, \
                "teamBottom" INTEGER, \
                "peopleMin" TEXT, \
                "peopleMax" INTEGER, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right"), \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max")\
                )
                """,
                """
                CREATE INDEX IF NOT EXISTS "index_child_on_parentA_parentB_parentC" ON "child"("parentA", "parentB", "parentC")
                """,
                """
                CREATE INDEX IF NOT EXISTS "index_child_on_COUNTRYLeft_COUNTRYRight" ON "child"("COUNTRYLeft", "COUNTRYRight")
                """,
                """
                CREATE INDEX IF NOT EXISTS "index_child_on_teamTop_teamBottom" ON "child"("teamTop", "teamBottom")
                """,
                """
                CREATE INDEX IF NOT EXISTS "index_child_on_peopleMin_peopleMax" ON "child"("peopleMin", "peopleMax")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_unique() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").unique()
                // Modified case of table name
                t.belongsTo("COUNTRY").unique()
                // Singularized table name
                t.belongsTo("team").unique()
                // Raw plural table name
                t.belongsTo("people").unique()
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentA" TEXT, \
                "parentB" CUSTOM TYPE, \
                "parentC", \
                "COUNTRYLeft" TEXT, \
                "COUNTRYRight" INTEGER, \
                "teamTop" TEXT, \
                "teamBottom" INTEGER, \
                "peopleMin" TEXT, \
                "peopleMax" INTEGER, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right"), \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max")\
                )
                """,
                """
                CREATE UNIQUE INDEX "index_child_on_parentA_parentB_parentC" ON "child"("parentA", "parentB", "parentC")
                """,
                """
                CREATE UNIQUE INDEX "index_child_on_COUNTRYLeft_COUNTRYRight" ON "child"("COUNTRYLeft", "COUNTRYRight")
                """,
                """
                CREATE UNIQUE INDEX "index_child_on_teamTop_teamBottom" ON "child"("teamTop", "teamBottom")
                """,
                """
                CREATE UNIQUE INDEX "index_child_on_peopleMin_peopleMax" ON "child"("peopleMin", "peopleMax")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_notIndexed() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", indexed: false)
                // Modified case of table name
                t.belongsTo("COUNTRY", indexed: false)
                // Singularized table name
                t.belongsTo("team", indexed: false)
                // Raw plural table name
                t.belongsTo("people", indexed: false)
                t.column("e")
            }
            
            XCTAssertEqual(lastSQLQuery, """
                CREATE TABLE "child" (\
                "a", \
                "parentA" TEXT, \
                "parentB" CUSTOM TYPE, \
                "parentC", \
                "COUNTRYLeft" TEXT, \
                "COUNTRYRight" INTEGER, \
                "teamTop" TEXT, \
                "teamBottom" INTEGER, \
                "peopleMin" TEXT, \
                "peopleMax" INTEGER, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right"), \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max")\
                )
                """)
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_notNull() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent").notNull()
                // Modified case of table name
                t.belongsTo("COUNTRY").notNull()
                // Singularized table name
                t.belongsTo("team").notNull()
                // Raw plural table name
                t.belongsTo("people").notNull()
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentA" TEXT NOT NULL, \
                "parentB" CUSTOM TYPE NOT NULL, \
                "parentC" NOT NULL, \
                "COUNTRYLeft" TEXT NOT NULL, \
                "COUNTRYRight" INTEGER NOT NULL, \
                "teamTop" TEXT NOT NULL, \
                "teamBottom" INTEGER NOT NULL, \
                "peopleMin" TEXT NOT NULL, \
                "peopleMax" INTEGER NOT NULL, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c"), \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right"), \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom"), \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max")\
                )
                """,
                """
                CREATE INDEX "index_child_on_parentA_parentB_parentC" ON "child"("parentA", "parentB", "parentC")
                """,
                """
                CREATE INDEX "index_child_on_COUNTRYLeft_COUNTRYRight" ON "child"("COUNTRYLeft", "COUNTRYRight")
                """,
                """
                CREATE INDEX "index_child_on_teamTop_teamBottom" ON "child"("teamTop", "teamBottom")
                """,
                """
                CREATE INDEX "index_child_on_peopleMin_peopleMax" ON "child"("peopleMin", "peopleMax")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_foreignKeyOptions() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "parent") { t in
                t.column("a", .text)
                t.column("b", .init(rawValue: "CUSTOM TYPE")) // Custom type
                t.column("c") // No declared type
                t.primaryKey(["a", "b", "c"])
            }
            
            try db.create(table: "country") { t in
                t.primaryKey {
                    t.column("left", .text)
                    t.column("right", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "teams") { t in
                t.primaryKey {
                    t.column("top", .text)
                    t.column("bottom", .integer)
                }
            }
            
            // Plural table
            try db.create(table: "people") { t in
                t.primaryKey {
                    t.column("min", .text)
                    t.column("max", .integer)
                }
            }
            
            clearSQLQueries()
            try db.create(table: "child") { t in
                t.column("a")
                t.belongsTo("parent", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Modified case of table name
                t.belongsTo("COUNTRY", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Singularized table name
                t.belongsTo("team", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                // Raw plural table name
                t.belongsTo("people", onDelete: .cascade, onUpdate: .setNull, deferred: true)
                t.column("e")
            }
            
            XCTAssertEqual(sqlQueries.suffix(5), [
                """
                CREATE TABLE "child" (\
                "a", \
                "parentA" TEXT, \
                "parentB" CUSTOM TYPE, \
                "parentC", \
                "COUNTRYLeft" TEXT, \
                "COUNTRYRight" INTEGER, \
                "teamTop" TEXT, \
                "teamBottom" INTEGER, \
                "peopleMin" TEXT, \
                "peopleMax" INTEGER, \
                "e", \
                FOREIGN KEY ("parentA", "parentB", "parentC") REFERENCES "parent"("a", "b", "c") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                FOREIGN KEY ("COUNTRYLeft", "COUNTRYRight") REFERENCES "COUNTRY"("left", "right") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                FOREIGN KEY ("teamTop", "teamBottom") REFERENCES "teams"("top", "bottom") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED, \
                FOREIGN KEY ("peopleMin", "peopleMax") REFERENCES "people"("min", "max") ON DELETE CASCADE ON UPDATE SET NULL DEFERRABLE INITIALLY DEFERRED\
                )
                """,
                """
                CREATE INDEX "index_child_on_parentA_parentB_parentC" ON "child"("parentA", "parentB", "parentC")
                """,
                """
                CREATE INDEX "index_child_on_COUNTRYLeft_COUNTRYRight" ON "child"("COUNTRYLeft", "COUNTRYRight")
                """,
                """
                CREATE INDEX "index_child_on_teamTop_teamBottom" ON "child"("teamTop", "teamBottom")
                """,
                """
                CREATE INDEX "index_child_on_peopleMin_peopleMax" ON "child"("peopleMin", "peopleMax")
                """,
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_autoreference_singular() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "employee") { t in
                t.primaryKey {
                    t.column("left")
                    t.column("right")
                }
                t.column("a")
                t.belongsTo("employee")
                t.belongsTo("custom", inTable: "employee")
                t.column("b")
            }
            
            XCTAssertEqual(sqlQueries.suffix(3), [
                """
                CREATE TABLE "employee" (\
                "left" NOT NULL, \
                "right" NOT NULL, \
                "a", \
                "employeeLeft", \
                "employeeRight", \
                "customLeft", \
                "customRight", \
                "b", \
                PRIMARY KEY ("left", "right"), \
                FOREIGN KEY ("employeeLeft", "employeeRight") REFERENCES "employee"("left", "right"), \
                FOREIGN KEY ("customLeft", "customRight") REFERENCES "employee"("left", "right")\
                )
                """,
                """
                CREATE INDEX "index_employee_on_employeeLeft_employeeRight" ON "employee"("employeeLeft", "employeeRight")
                """,
                """
                CREATE INDEX "index_employee_on_customLeft_customRight" ON "employee"("customLeft", "customRight")
                """
            ])
        }
    }
    
    func testTable_belongsTo_compositePrimaryKey_autoreference_plural() throws {
        try makeDatabaseQueue().inDatabase { db in
            try db.create(table: "employees") { t in
                t.primaryKey {
                    t.column("left")
                    t.column("right")
                }
                t.column("a")
                t.belongsTo("employee")
                t.belongsTo("custom", inTable: "employees")
                t.column("b")
            }
            
            XCTAssertEqual(sqlQueries.suffix(3), [
                """
                CREATE TABLE "employees" (\
                "left" NOT NULL, \
                "right" NOT NULL, \
                "a", \
                "employeeLeft", \
                "employeeRight", \
                "customLeft", \
                "customRight", \
                "b", \
                PRIMARY KEY ("left", "right"), \
                FOREIGN KEY ("employeeLeft", "employeeRight") REFERENCES "employees"("left", "right"), \
                FOREIGN KEY ("customLeft", "customRight") \
                REFERENCES "employees"("left", "right")\
                )
                """,
                """
                CREATE INDEX "index_employees_on_employeeLeft_employeeRight" ON "employees"("employeeLeft", "employeeRight")
                """,
                """
                CREATE INDEX "index_employees_on_customLeft_customRight" ON "employees"("customLeft", "customRight")
                """
            ])
        }
    }
    
    func testTable_belongsTo_as_primary_key() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.create(table: "composite") { t in
                t.primaryKey {
                    t.column("a", .text)
                    t.column("b", .text)
                }
            }
            try db.create(table: "simple") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            do {
                try db.create(table: "compositeChild") { t in
                    t.primaryKey {
                        t.belongsTo("composite")
                    }
                }
                assertEqualSQL(lastSQLQuery!, """
                    CREATE TABLE "compositeChild" (\
                    "compositeA" TEXT NOT NULL, \
                    "compositeB" TEXT NOT NULL, \
                    PRIMARY KEY ("compositeA", "compositeB"), \
                    FOREIGN KEY ("compositeA", "compositeB") REFERENCES "composite"("a", "b")\
                    )
                    """)
            }
            
            do {
                try db.create(table: "simpleChild") { t in
                    t.primaryKey {
                        t.belongsTo("simple")
                    }
                }
                assertEqualSQL(lastSQLQuery!, """
                    CREATE TABLE "simpleChild" (\
                    "simpleId" INTEGER NOT NULL REFERENCES "simple"("id"), \
                    PRIMARY KEY ("simpleId")\
                    )
                    """)
            }
            
            do {
                try db.create(table: "complex") { t in
                    t.primaryKey {
                        t.column("a")
                        t.belongsTo("composite")
                        t.belongsTo("simple")
                        t.column("b")
                    }
                }
                assertEqualSQL(lastSQLQuery!, """
                    CREATE TABLE "complex" (\
                    "a" NOT NULL, \
                    "compositeA" TEXT NOT NULL, \
                    "compositeB" TEXT NOT NULL, \
                    "simpleId" INTEGER NOT NULL REFERENCES "simple"("id"), \
                    "b" NOT NULL, \
                    PRIMARY KEY ("a", "compositeA", "compositeB", "simpleId", "b"), \
                    FOREIGN KEY ("compositeA", "compositeB") REFERENCES "composite"("a", "b")\
                    )
                    """)
            }
        }
    }
    
    func testTable_invalid_belongsTo_as_primary_key() throws {
        try makeDatabaseQueue().inDatabase { db in
            do {
                // Invalid circular definition
                try db.create(table: "player") { t in
                    t.primaryKey {
                        t.belongsTo("player")
                    }
                }
                XCTFail("Expected error")
            } catch { }
        }
    }
}
