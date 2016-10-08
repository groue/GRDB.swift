import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Hacker : TableMapping {
    static let databaseTableName = "hackers"
}

private struct Person : TableMapping {
    static let databaseTableName = "persons"
}

private struct Citizenship : TableMapping {
    static let databaseTableName = "citizenships"
}


class DeleteByKeyTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute("CREATE TABLE hackers (name TEXT)")
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            try db.execute("CREATE TABLE citizenships (personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
        }
    }
    
    func testImplicitRowIDPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var deleted = try Hacker.deleteOne(db, key: 1)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" = 1")
                XCTAssertFalse(deleted)
                
                try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
                deleted = try Hacker.deleteOne(db, key: 1)
                XCTAssertTrue(deleted)
                XCTAssertEqual(Hacker.fetchCount(db), 0)
                
                try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [1, "Arthur"])
                try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [2, "Barbara"])
                try db.execute("INSERT INTO hackers (rowid, name) VALUES (?, ?)", arguments: [3, "Craig"])
                let deletedCount = try Hacker.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"hackers\" WHERE \"rowid\" IN (2,3,4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(Hacker.fetchCount(db), 1)
            }
        }
    }
    
    func testSingleColumnPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var deleted = try Person.deleteOne(db, key: 1)
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" = 1")
                XCTAssertFalse(deleted)
                
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                deleted = try Person.deleteOne(db, key: 1)
                XCTAssertTrue(deleted)
                XCTAssertEqual(Person.fetchCount(db), 0)

                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, keys: [2, 3, 4])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE \"id\" IN (2,3,4)")
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(Person.fetchCount(db), 1)
            }
        }
    }
    
    func testMultipleColumnPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"citizenships\" WHERE (\"personId\" = 1 AND \"countryIsoCode\" = 'FR')")
                XCTAssertFalse(deleted)
                
                try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
                deleted = try Citizenship.deleteOne(db, key: ["personId": 1, "countryIsoCode": "FR"])
                XCTAssertTrue(deleted)
                XCTAssertEqual(Citizenship.fetchCount(db), 0)
                
                try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "FR"])
                try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [1, "US"])
                try db.execute("INSERT INTO citizenships (personId, countryIsoCode) VALUES (?, ?)", arguments: [2, "US"])
                let deletedCount = try Citizenship.deleteAll(db, keys: [["personId": 1, "countryIsoCode": "FR"], ["personId": 1, "countryIsoCode": "US"], ["personId": 1, "countryIsoCode": "DE"]])
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(Citizenship.fetchCount(db), 1)
            }
        }
    }
    
    func testUniqueIndex() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"email\" = 'arthur@example.com')")
                XCTAssertFalse(deleted)
                
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                deleted = try Person.deleteOne(db, key: ["email": "arthur@example.com"])
                XCTAssertTrue(deleted)
                XCTAssertEqual(Person.fetchCount(db), 0)
                
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, keys: [["email": "arthur@example.com"], ["email": "barbara@example.com"], ["email": "david@example.com"]])
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(Person.fetchCount(db), 1)
            }
        }
    }
    
    func testImplicitUniqueIndexOnSingleColumnPrimaryKey() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var deleted = try Person.deleteOne(db, key: ["id": 1])
                XCTAssertEqual(self.lastSQLQuery, "DELETE FROM \"persons\" WHERE (\"id\" = 1)")
                XCTAssertFalse(deleted)
                
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                deleted = try Person.deleteOne(db, key: ["id": 1])
                XCTAssertTrue(deleted)
                XCTAssertEqual(Person.fetchCount(db), 0)
                
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [1, "Arthur", "arthur@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [2, "Barbara", "barbara@example.com"])
                try db.execute("INSERT INTO persons (id, name, email) VALUES (?, ?, ?)", arguments: [3, "Craig", "craig@example.com"])
                let deletedCount = try Person.deleteAll(db, keys: [["id": 2], ["id": 3], ["id": 4]])
                XCTAssertEqual(deletedCount, 2)
                XCTAssertEqual(Person.fetchCount(db), 1)
            }
        }
    }
}
