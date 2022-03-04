import XCTest
import GRDB

private class Reader : Record {
    var id: Int64?
    let name: String
    let age: Int?
    
    init(id: Int64?, name: String, age: Int?) {
        self.id = id
        self.name = name
        self.age = age
        super.init()
    }
    
    required init(row: Row) throws {
        self.id = try row["id"]
        self.name = try row["name"]
        self.age = try row["age"]
        try super.init(row: row)
    }
    
    override class var databaseTableName: String {
        "readers"
    }
    
    override func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["age"] = age
    }
    
    override func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}


class RecordQueryInterfaceRequestTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createReaders") { db in
            try db.execute(sql: """
                CREATE TABLE readers (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    age INT)
                """)
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Fetch Record
    
    func testFetch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            let arthur = Reader(id: nil, name: "Arthur", age: 42)
            try arthur.insert(db)
            let barbara = Reader(id: nil, name: "Barbara", age: 36)
            try barbara.insert(db)
            
            let request = Reader.all()
            
            do {
                let readers = try request.fetchAll(db)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(readers.count, 2)
                XCTAssertEqual(readers[0].id!, arthur.id!)
                XCTAssertEqual(readers[0].name, arthur.name)
                XCTAssertEqual(readers[0].age, arthur.age)
                XCTAssertEqual(readers[1].id!, barbara.id!)
                XCTAssertEqual(readers[1].name, barbara.name)
                XCTAssertEqual(readers[1].age, barbara.age)
            }
            
            do {
                let reader = try request.fetchOne(db)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" LIMIT 1")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let cursor = try request.fetchCursor(db)
                let names = cursor.map(\.name)
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
                
                // validate query *after* cursor has retrieved a record
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
            }
        }
    }
}
