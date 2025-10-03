import XCTest
import GRDB

// Table records
private struct Hacker : TableRecord {
    static let databaseTableName = "hackers"
    var id: Int64? // Optional
}

extension Hacker: Identifiable { }

private struct Person : Codable, PersistableRecord, FetchableRecord, Hashable {
    static let databaseTableName = "persons"
    var id: Int64 // Non-optional
    var name: String
    var email: String
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }
}

extension Person: Identifiable { }

private struct Citizenship : TableRecord {
    static let databaseTableName = "citizenships"
}

// View records

private struct PersonView : Codable, PersistableRecord, FetchableRecord, Hashable {
    static let databaseTableName = "personsView"
    var id: Int64 // Non-optional
    var name: String
    var email: String
    
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
    }
}

extension PersonView: Identifiable { }

private struct CitizenshipView : TableRecord {
    static let databaseTableName = "citizenshipsView"
}

// Schema source

private struct ViewSchemaSource: DatabaseSchemaSource {
    func columnsForPrimaryKey(_ db: Database, inView view: DatabaseObjectID) throws -> [String]? {
        switch view.name {
        case "personsView":
            return ["id"]
        case "citizenshipsView":
            return ["personId", "countryIsoCode"]
        default:
            return nil
        }
    }
}

class TableRecordDeleteTests: GRDBTestCase {
    
    override func setup(_ dbWriter: some DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute(sql: "CREATE TABLE hackers (name TEXT)")
            try db.execute(sql: "CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            try db.execute(sql: "CREATE TABLE citizenships (personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
            
            // mutable views
            try db.execute(sql: """
                CREATE VIEW personsView AS SELECT * FROM persons;
                -- Insert trigger
                CREATE TRIGGER personsView_insert
                INSTEAD OF INSERT ON personsView
                BEGIN
                  INSERT INTO persons (id, name, email)
                  VALUES (NEW.id, NEW.name, NEW.email);
                END;
                -- Delete trigger
                CREATE TRIGGER personsView_delete
                INSTEAD OF DELETE ON personsView
                BEGIN
                  DELETE FROM persons WHERE id = OLD.id;
                END;
                """)
            try db.execute(sql: """
                CREATE VIEW citizenshipsView AS SELECT * FROM citizenships;
                -- Insert trigger
                CREATE TRIGGER citizenshipsView_insert
                INSTEAD OF INSERT ON citizenshipsView
                BEGIN
                  INSERT INTO citizenships (personId, countryIsoCode)
                  VALUES (NEW.personId, NEW.countryIsoCode);
                END;
                -- Delete trigger
                CREATE TRIGGER citizenshipsView_delete
                INSTEAD OF DELETE ON citizenshipsView
                BEGIN
                  DELETE FROM citizenships WHERE personId = OLD.personId AND countryIsoCode = OLD.countryIsoCode;
                END;
                """)
        }
    }
    
    func testImplicitRowIDPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Hacker.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            try XCTAssertFalse(Hacker.deleteOne(db, id: nil))
            deleted = try Hacker.deleteOne(db, id: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Hacker.fetchCount(db), 0)
            
            do {
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
                let deletedCount = try Hacker.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Hacker.fetchCount(db), 1)
            }
            
            do {
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
                try db.execute(sql: "INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
                let deletedCount = try Hacker.deleteAll(db, ids: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Hacker.fetchCount(db), 1)
            }
        }
    }

    func testSingleColumnPrimaryKey_table() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, id: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            do {
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Person.fetchCount(db), 1)
            }
            
            do {
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, ids: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try Person.fetchCount(db), 1)
            }
        }
    }

    func testSingleColumnPrimaryKey_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try PersonView.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try PersonView.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try PersonView.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try PersonView.deleteOne(db, id: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try PersonView.fetchCount(db), 0)
            
            do {
                try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try PersonView.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try PersonView.fetchCount(db), 1)
            }
            
            do {
                try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try PersonView.deleteAll(db, ids: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (2, 3, 4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(try PersonView.fetchCount(db), 1)
            }
        }
    }

    func testMultipleColumnPrimaryKey_table() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"citizenships\" WHERE (\"personId\" = 1) AND (\"countryIsoCode\" = 'FR')")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Citizenship.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "US"])
            try db.execute(sql: "INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [2, "US"])
            let deletedCount = try Citizenship.deleteAll(db, keys: [["personId": 1, "countryIsoCode": "FR"], ["personId": 1, "countryIsoCode": "US"], ["personId": 1, "countryIsoCode": "DE"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Citizenship.fetchCount(db), 1)
        }
    }

    func testMultipleColumnPrimaryKey_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try CitizenshipView.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"citizenshipsView\" WHERE (\"personId\" = 1) AND (\"countryIsoCode\" = 'FR')")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO citizenshipsView (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            deleted = try CitizenshipView.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try CitizenshipView.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO citizenshipsView (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            try db.execute(sql: "INSERT INTO citizenshipsView (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "US"])
            try db.execute(sql: "INSERT INTO citizenshipsView (personId, countryIsoCode) VALUES (?, ?)", arguments: [2, "US"])
            let deletedCount = try CitizenshipView.deleteAll(db, keys: [["personId": 1, "countryIsoCode": "FR"], ["personId": 1, "countryIsoCode": "US"], ["personId": 1, "countryIsoCode": "DE"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try CitizenshipView.fetchCount(db), 1)
        }
    }

    func testUniqueIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"email\" = 'arthur@example.com'")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["email": "arthur@example.com"], ["email": "barbara@example.com"], ["email": "david@example.com"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }

    func testImplicitUniqueIndexOnSingleColumnPrimaryKey_table() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute(sql: "INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["id": 2], ["id": 3], ["id": 4]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }
    
    func testImplicitUniqueIndexOnSingleColumnPrimaryKey_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try PersonView.deleteOne(db, key: ["id": 1])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1")
            XCTAssertFalse(deleted)
            
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try PersonView.deleteOne(db, key: ["id": 1])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try PersonView.fetchCount(db), 0)
            
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute(sql: "INSERT INTO personsView (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try PersonView.deleteAll(db, keys: [["id": 2], ["id": 3], ["id": 4]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try PersonView.fetchCount(db), 1)
        }
    }
    
    func testRequestDeleteAll_table() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try Person.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.filter { $0.name == "Arthur" }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"name\" = 'Arthur'")
            
            try Person.filter(key: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            
            try Person.filter(keys: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2)")
            
            try Person.filter(id: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
            
            try Person.filter(ids: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2)")
            
            try Person.filter(sql: "id = 1").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE id = 1")
            
            try Person.filter(sql: "id = 1").filter { $0.name == "Arthur" }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (id = 1) AND (\"name\" = 'Arthur')")

            try Person.select { $0.name }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.order { $0.name }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Person.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1")
                
                try Person.order { $0.name }.deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
                
                try Person.order { $0.name }.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" LIMIT 1")
                
                try Person.order { $0.name }.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" DESC LIMIT 1 OFFSET 2")
                
                try Person.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1 OFFSET 2")
            }
        }
    }
    
    func testRequestDeleteAll_view() throws {
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try PersonView.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\"")
            
            try PersonView.filter { $0.name == "Arthur" }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"name\" = 'Arthur'")
            
            try PersonView.filter(key: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1")
            
            try PersonView.filter(keys: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (1, 2)")
            
            try PersonView.filter(id: 1).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1")
            
            try PersonView.filter(ids: [1, 2]).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (1, 2)")
            
            try PersonView.filter(sql: "id = 1").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE id = 1")
            
            try PersonView.filter(sql: "id = 1").filter { $0.name == "Arthur" }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE (id = 1) AND (\"name\" = 'Arthur')")

            try PersonView.select { $0.name }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\"")
            
            try PersonView.order { $0.name }.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\"")
            
            if try String.fetchCursor(db, sql: "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try PersonView.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" LIMIT 1")
                
                try PersonView.order { $0.name }.deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\"")
                
                try PersonView.order { $0.name }.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" ORDER BY \"name\" LIMIT 1")
                
                try PersonView.order { $0.name }.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" ORDER BY \"name\" DESC LIMIT 1 OFFSET 2")
                
                try PersonView.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" LIMIT 1 OFFSET 2")
            }
        }
    }
    
    func testRequestDeleteAndFetchStatement_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, select: { [$0.name] })
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING \"name\"")
                XCTAssertEqual(statement.columnNames, ["name"])
            }
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING *")
                XCTAssertEqual(statement.columnNames, ["id", "name", "email"])
            }
            do {
                let request = Person.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns(excluding: ["name"])])
                XCTAssertEqual(statement.sql, "DELETE FROM \"persons\" RETURNING \"id\", \"email\"")
                XCTAssertEqual(statement.columnNames, ["id", "email"])
            }
        }
    }
    
    func testRequestDeleteAndFetchStatement_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            do {
                let request = PersonView.all()
                let statement = try request.deleteAndFetchStatement(db, select: { [$0.name] })
                XCTAssertEqual(statement.sql, "DELETE FROM \"personsView\" RETURNING \"name\"")
                XCTAssertEqual(statement.columnNames, ["name"])
            }
            do {
                let request = PersonView.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, "DELETE FROM \"personsView\" RETURNING *")
                XCTAssertEqual(statement.columnNames, ["id", "name", "email"])
            }
            do {
                let request = PersonView.all()
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns(excluding: ["name"])])
                XCTAssertEqual(statement.sql, "DELETE FROM \"personsView\" RETURNING \"id\", \"email\"")
                XCTAssertEqual(statement.columnNames, ["id", "email"])
            }
        }
    }
    
    func testRequestDeleteAndFetchCursor_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            _ = try Person.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.filter { $0.name == "Arthur" }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"name\" = 'Arthur' RETURNING *")
            
            _ = try Person.filter(key: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try Person.filter(keys: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2) RETURNING *")
            
            _ = try Person.filter(id: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try Person.filter(ids: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (1, 2) RETURNING *")
            
            _ = try Person.filter(sql: "id = 1").deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE id = 1 RETURNING *")
            
            _ = try Person.filter(sql: "id = 1").filter { $0.name == "Arthur" }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (id = 1) AND (\"name\" = 'Arthur') RETURNING *")

            _ = try Person.select { $0.name }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            _ = try Person.order { $0.name }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" RETURNING *")
            
            // No test for LIMIT ... RETURNING ... since this is not supported by SQLite
        }
    }
    
    func testRequestDeleteAndFetchCursor_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            _ = try PersonView.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" RETURNING *")
            
            _ = try PersonView.all().deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" RETURNING *")
            
            _ = try PersonView.filter { $0.name == "Arthur" }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"name\" = 'Arthur' RETURNING *")
            
            _ = try PersonView.filter(key: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try PersonView.filter(keys: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (1, 2) RETURNING *")
            
            _ = try PersonView.filter(id: 1).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" = 1 RETURNING *")
            
            _ = try PersonView.filter(ids: [1, 2]).deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE \"id\" IN (1, 2) RETURNING *")
            
            _ = try PersonView.filter(sql: "id = 1").deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE id = 1 RETURNING *")
            
            _ = try PersonView.filter(sql: "id = 1").filter { $0.name == "Arthur" }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" WHERE (id = 1) AND (\"name\" = 'Arthur') RETURNING *")

            _ = try PersonView.select { $0.name }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" RETURNING *")
            
            _ = try PersonView.order { $0.name }.deleteAndFetchCursor(db).next()
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"personsView\" RETURNING *")
            
            // No test for LIMIT ... RETURNING ... since this is not supported by SQLite
        }
    }
    
    func testRequestDeleteAndFetchArray_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter { $0.id != 2 }
            let deletePersons = try request
                .deleteAndFetchAll(db)
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(deletePersons, [
                Person(id: 1, name: "Arthur", email: "arthur@example.com"),
                Person(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchArray_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try PersonView(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try PersonView(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try PersonView(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = PersonView.filter { $0.id != 2 }
            let deletePersons = try request
                .deleteAndFetchAll(db)
                .sorted(by: { $0.id < $1.id })
            XCTAssertEqual(deletePersons, [
                PersonView(id: 1, name: "Arthur", email: "arthur@example.com"),
                PersonView(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchSet_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter { $0.id != 2 }
            let deletePersons = try request.deleteAndFetchSet(db)
            XCTAssertEqual(deletePersons, [
                Person(id: 1, name: "Arthur", email: "arthur@example.com"),
                Person(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchSet_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try PersonView(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try PersonView(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try PersonView(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = PersonView.filter { $0.id != 2 }
            let deletePersons = try request.deleteAndFetchSet(db)
            XCTAssertEqual(deletePersons, [
                PersonView(id: 1, name: "Arthur", email: "arthur@example.com"),
                PersonView(id: 3, name: "Craig", email: "craig@example.com"),
            ])
        }
    }
    
    func testRequestDeleteAndFetchIds_table() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try Person(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try Person(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try Person(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = Person.filter { $0.id != 2 }
            let deletedIds = try request.deleteAndFetchIds(db)
            XCTAssertEqual(deletedIds, [1, 3])
        }
    }
    
    func testRequestDeleteAndFetchIds_view() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        // Views need a schema source
        dbConfiguration.schemaSource = ViewSchemaSource()
        
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try PersonView(id: 1, name: "Arthur", email: "arthur@example.com").insert(db)
            try PersonView(id: 2, name: "Barbara", email: "barbara@example.com").insert(db)
            try PersonView(id: 3, name: "Craig", email: "craig@example.com").insert(db)

            let request = PersonView.filter { $0.id != 2 }
            let deletedIds = try request.deleteAndFetchIds(db)
            XCTAssertEqual(deletedIds, [1, 3])
        }
    }
    
    // TODO: duplicate test with views?
    func testJoinedRequestDeleteAll() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord {
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
            }
            
            do {
                try Player.including(required: Player.team).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId")
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                try Player.aliased(alias).including(required: Player.team).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId")
                    """)
            }
            do {
                try Team.having(Team.players.isEmpty).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0)
                    """)
            }
            do {
                try Team.including(all: Team.players).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team"
                    """)
            }
        }
    }
    
    // TODO: duplicate test with views?
    func testJoinedRequestDeleteAndFetch() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord, FetchableRecord {
                static let team = belongsTo(Team.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            
            struct Team: MutablePersistableRecord, FetchableRecord {
                // Test RETURNING
                static var databaseSelection: [any SQLSelectable] { [Column("id"), Column("name")] }
                static let players = hasMany(Player.self)
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            
            try db.create(table: "team") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text)
            }
            
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.belongsTo("team")
            }
            
            do {
                let request = Player.including(required: Player.team)
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId") \
                    RETURNING *
                    """)
                XCTAssertEqual(statement.columnNames, ["id", "teamId"])
                
                _ = try request.deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "player"."id" \
                    FROM "player" \
                    JOIN "team" ON "team"."id" = "player"."teamId") \
                    RETURNING *
                    """)
            }
            do {
                let alias = TableAlias(name: "p")
                _ = try Player.aliased(alias).including(required: Player.team).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "p"."id" \
                    FROM "player" "p" \
                    JOIN "team" ON "team"."id" = "p"."teamId") \
                    RETURNING *
                    """)
            }
            do {
                let request = Team.having(Team.players.isEmpty)
                let statement = try request.deleteAndFetchStatement(db, selection: [.allColumns])
                XCTAssertEqual(statement.sql, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0) \
                    RETURNING *
                    """)
                XCTAssertEqual(statement.columnNames, ["id", "name"])
                
                _ = try request.deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" WHERE "id" IN (\
                    SELECT "team"."id" \
                    FROM "team" \
                    LEFT JOIN "player" ON "player"."teamId" = "team"."id" \
                    GROUP BY "team"."id" \
                    HAVING COUNT(DISTINCT "player"."id") = 0) \
                    RETURNING "id", "name"
                    """)
            }
            do {
                _ = try Team.including(all: Team.players).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "team" RETURNING "id", "name"
                    """)
            }
        }
    }
    
    func testGroupedRequestDeleteAll() throws {
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                try Player.all().groupByPrimaryKey().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id")
                    """)
            }
            do {
                try Player.all().group(-Column("id")).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY -"id")
                    """)
            }
            do {
                try Player.all().group(Column.rowID).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().groupByPrimaryKey().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
            do {
                try Passport.all().group(Column.rowID).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid")
                    """)
            }
        }
    }
    
    func testGroupedRequestDeleteAndFetchCursor() throws {
#if GRDBCUSTOMSQLITE || SQLITE_HAS_CODEC
        guard Database.sqliteLibVersionNumber >= 3035000 else {
            throw XCTSkip("RETURNING clause is not available")
        }
#else
        guard #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) else {
            throw XCTSkip("RETURNING clause is not available")
        }
#endif
        
        try makeDatabaseQueue().inDatabase { db in
            struct Player: MutablePersistableRecord, FetchableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            struct Passport: MutablePersistableRecord, FetchableRecord {
                func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
                init(row: Row) { preconditionFailure("should not be called") }
            }
            try db.create(table: "player") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("score", .integer)
            }
            try db.create(table: "passport") { t in
                t.column("countryCode", .text).notNull()
                t.column("citizenId", .integer).notNull()
                t.primaryKey(["countryCode", "citizenId"])
            }
            do {
                _ = try Player.all().groupByPrimaryKey().deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "id") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Player.all().group(-Column("id")).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY -"id") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Player.all().group(Column.rowID).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "player" WHERE "id" IN (\
                    SELECT "id" \
                    FROM "player" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Passport.all().groupByPrimaryKey().deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
            do {
                _ = try Passport.all().group(Column.rowID).deleteAndFetchCursor(db).next()
                XCTAssertEqual(self.lastSQLQuery, """
                    DELETE FROM "passport" WHERE "rowid" IN (\
                    SELECT "rowid" \
                    FROM "passport" \
                    GROUP BY "rowid") \
                    RETURNING *
                    """)
            }
        }
    }
}
