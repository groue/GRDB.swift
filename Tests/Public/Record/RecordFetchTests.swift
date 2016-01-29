import XCTest
import GRDB

class RecordFetchTests: GRDBTestCase {
    
    override func setUp() {
        super.setUp()
        
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createPerson", migrate: Person.setupInDatabase)
        assertNoError {
            try migrator.migrate(dbQueue)
        }
    }
    
    
    func testSelectStatement() {
        assertNoError {
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
