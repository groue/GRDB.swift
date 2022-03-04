import XCTest
import GRDB

private struct Reader: Hashable {
    var id: Int64?
    let name: String
    let age: Int?
}

extension Reader : FetchableRecord {
    init(row: Row) throws {
        id = try row["id"]
        name = try row["name"]
        age = try row["age"]
    }
}

extension Reader : MutablePersistableRecord {
    static let databaseTableName = "readers"
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["name"] = name
        container["age"] = age
    }
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

private struct AltReader {
    var id: Int64?
    let name: String
    let age: Int?
}

extension AltReader : FetchableRecord {
    init(row: Row) throws {
        id = try row["id"]
        name = try row["name"]
        age = try row["age"]
    }
}


class FetchableRecordQueryInterfaceRequestTests: GRDBTestCase {
    
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
    
    
    // MARK: - Fetch FetchableRecord
    
    func testAll() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var arthur = Reader(id: nil, name: "Arthur", age: 42)
            try arthur.insert(db)
            var barbara = Reader(id: nil, name: "Barbara", age: 36)
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
                let names = try request.fetchCursor(db).map(\.name)
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
                
                // validate query *after* cursor has retrieved a record
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
            }
        }
    }

    func testFetch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var arthur = Reader(id: nil, name: "Arthur", age: 42)
            try arthur.insert(db)
            var barbara = Reader(id: nil, name: "Barbara", age: 36)
            try barbara.insert(db)
            
            do {
                let readers = try Reader.fetchAll(db)
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
                let readers = try Reader.fetchSet(db)
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(readers.count, 2)
                XCTAssertEqual(Set(readers.map(\.id)), [arthur.id!, barbara.id!])
                XCTAssertEqual(Set(readers.map(\.name)), [arthur.name, barbara.name])
                XCTAssertEqual(Set(readers.map(\.age)), [arthur.age, barbara.age])
            }
            
            do {
                let reader = try Reader.fetchOne(db)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" LIMIT 1")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let cursor = try Reader.fetchCursor(db)
                let names = cursor.map(\.name)
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
                
                // validate query *after* cursor has retrieved a record
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
            }

            do {
                let reader = try Reader.limit(1, offset: 1).fetchOne(db)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" LIMIT 1 OFFSET 1")
                XCTAssertEqual(reader.id!, barbara.id!)
                XCTAssertEqual(reader.name, barbara.name)
                XCTAssertEqual(reader.age, barbara.age)
            }
        }
    }

    func testAlternativeFetch() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            var arthur = Reader(id: nil, name: "Arthur", age: 42)
            try arthur.insert(db)
            var barbara = Reader(id: nil, name: "Barbara", age: 36)
            try barbara.insert(db)
            
            let request = Reader.all()
            
            do {
                let readers = try AltReader.fetchAll(db, request)
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
                let reader = try AltReader.fetchOne(db, request)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\" LIMIT 1")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let names = try AltReader.fetchCursor(db, request).map(\.name)
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
                
                // validate query *after* cursor has retrieved a record
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
            }
        }
    }
}
