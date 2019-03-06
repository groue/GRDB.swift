import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Hacker : MutablePersistableRecord {
    static let databaseTableName = "hackers"
    func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
}

private struct Person : MutablePersistableRecord {
    static let databaseTableName = "persons"
    func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
}

private struct Citizenship : MutablePersistableRecord {
    static let databaseTableName = "citizenships"
    func encode(to container: inout PersistenceContainer) { preconditionFailure("should not be called") }
}


class MutablePersistableRecordDeleteTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute("CREATE TABLE hackers (name TEXT)")
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            try db.execute("CREATE TABLE citizenships (personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
        }
    }
    
    func testImplicitRowIDPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE (\"rowid\" = 1)")
            XCTAssertFalse(deleted)
            
            try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            deleted = try Hacker.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Hacker.fetchCount(db), 0)
            
            try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
            try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
            try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
            let deletedCount = try Hacker.deleteAll(db, keys: [2, 3, 4])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE (\"rowid\" IN (2, 3, 4))")
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Hacker.fetchCount(db), 1)
        }
    }

    func testSingleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: 1)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"id\" = 1)")
            XCTAssertFalse(deleted)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: 1)
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [2, 3, 4])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"id\" IN (2, 3, 4))")
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }

    func testMultipleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"citizenships\" WHERE ((\"personId\" = 1) AND (\"countryIsoCode\" = 'FR'))")
            XCTAssertFalse(deleted)
            
            try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Citizenship.fetchCount(db), 0)
            
            try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
            try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "US"])
            try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [2, "US"])
            let deletedCount = try Citizenship.deleteAll(db, keys: [["personId": 1, "countryIsoCode": "FR"], ["personId": 1, "countryIsoCode": "US"], ["personId": 1, "countryIsoCode": "DE"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Citizenship.fetchCount(db), 1)
        }
    }

    func testUniqueIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"email\" = 'arthur@example.com')")
            XCTAssertFalse(deleted)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["email": "arthur@example.com"], ["email": "barbara@example.com"], ["email": "david@example.com"]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }

    func testImplicitUniqueIndexOnSingleColumnPrimaryKey() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"id\" = 1)")
            XCTAssertFalse(deleted)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            deleted = try Person.deleteOne(db, key: ["id": 1])
            XCTAssertTrue(deleted)
            XCTAssertEqual(try Person.fetchCount(db), 0)
            
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
            try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
            let deletedCount = try Person.deleteAll(db, keys: [["id": 2], ["id": 3], ["id": 4]])
            XCTAssertEqual(deletedCount, 2)
            XCTAssertEqual(try Person.fetchCount(db), 1)
        }
    }
    
    func testRequestDelete() throws {
        let dbQueue = try makeDatabaseQueue()
        
        try dbQueue.inDatabase { db in
            try Person.deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.filter(Column("name") == "Arthur").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"name\" = 'Arthur')")
            
            try Person.filter(sql: "id = 1").deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (id = 1)")
            
            try Person.select(Column("name")).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            try Person.order(Column("name")).deleteAll(db)
            XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\"")
            
            // TODO: find out when ENABLE_UPDATE_DELETE_LIMIT is not there.
            // iOS8.1 can't run those tests, for example.
            if try String.fetchAll(db, "PRAGMA COMPILE_OPTIONS").contains("ENABLE_UPDATE_DELETE_LIMIT") {
                try Person.limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1")
                
                try Person.order(Column("name")).limit(1).deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" LIMIT 1")
                
                try Person.order(Column("name")).limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" ORDER BY \"name\" DESC LIMIT 1 OFFSET 2")
                
                try Person.limit(1, offset: 2).reversed().deleteAll(db)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" LIMIT 1 OFFSET 2")
            }
        }
    }
}
