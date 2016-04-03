import XCTest
#if SQLITE_HAS_CODEC
    import GRDBCipher
#else
    import GRDB
#endif

class RecordFetchTests: GRDBTestCase {
    
    override func setUpDatabase(dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setupInDatabase)
        try migrator.migrate(dbWriter)
    }
    
    
    func testSelectStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)
                return .Commit
            }
            
            try dbQueue.inDatabase { db in
                let statement = try db.selectStatement("SELECT * FROM persons WHERE name = ?")
                
                for name in ["Arthur", "Barbara"] {
                    let person = Person.fetchOne(statement, arguments: [name])!
                    XCTAssertEqual(person.name!, name)
                }
            }
        }
    }
    
    func testDatabaseRecordSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)
                
                let personSequence = Person.fetch(db, "SELECT * FROM persons ORDER BY name")
                var names1: [String?] = personSequence.map { $0.name }
                var names2: [String?] = personSequence.map { $0.name }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
    
    func testSelectStatementRecordSequenceCanBeIteratedTwice() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inTransaction { db in
                try Person(name: "Arthur", age: 41).insert(db)
                try Person(name: "Barbara", age: 37).insert(db)

                let statement = try db.selectStatement("SELECT * FROM persons ORDER BY name")
                let personSequence = Person.fetch(statement)
                var names1: [String?] = personSequence.map { $0.name }
                var names2: [String?] = personSequence.map { $0.name }
                
                XCTAssertEqual(names1[0]!, "Arthur")
                XCTAssertEqual(names1[1]!, "Barbara")
                XCTAssertEqual(names2[0]!, "Arthur")
                XCTAssertEqual(names2[1]!, "Barbara")
                
                return .Commit
            }
        }
    }
}
