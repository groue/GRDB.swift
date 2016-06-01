import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private class Person : Record {
    var id: Int64!
    var name: String!
    var age: Int?
    
    init(id: Int64? = nil, name: String? = nil, age: Int? = nil) {
        self.id = id
        self.name = name
        self.age = age
        super.init()
    }
    
    static func setupInDatabase(db: Database) throws {
        try db.execute(
            "CREATE TABLE persons (" +
                "id INTEGER PRIMARY KEY, " +
                "name TEXT NOT NULL, " +
                "age INT" +
            ")")
    }
    
    // Record
    
    override class func databaseTableName() -> String {
        return "persons"
    }
    
    required init(_ row: Row) {
        id = row.value(named: "id")
        age = row.value(named: "age")
        name = row.value(named: "name")
        super.init(row)
    }
    
    override var persistentDictionary: [String: DatabaseValueConvertible?] {
        return [
            "id": id,
            "name": name,
            "age": age,
        ]
    }
    
    override func didInsertWithRowID(rowID: Int64, forColumn column: String?) {
        self.id = rowID
    }
}

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
