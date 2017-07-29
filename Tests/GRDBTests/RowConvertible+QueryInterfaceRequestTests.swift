import XCTest
#if GRDBCIPHER
    import GRDBCipher
#elseif GRDBCUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct Reader {
    var id: Int64?
    let name: String
    let age: Int?
}

extension Reader : RowConvertible {
    init(row: Row) {
        id = row["id"]
        name = row["name"]
        age = row["age"]
    }
}

extension Reader : MutablePersistable {
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

extension AltReader : RowConvertible {
    init(row: Row) {
        id = row["id"]
        name = row["name"]
        age = row["age"]
    }
}


class RowConvertibleQueryInterfaceRequestTests: GRDBTestCase {
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createReaders") { db in
            try db.execute(
                "CREATE TABLE readers (" +
                    "id INTEGER PRIMARY KEY, " +
                    "name TEXT NOT NULL, " +
                    "age INT" +
                ")")
        }
        try migrator.migrate(dbWriter)
    }
    
    
    // MARK: - Fetch RowConvertible
    
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
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let names = try request.fetchCursor(db).map { $0.name }
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
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
                let reader = try Reader.fetchOne(db)!
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let cursor = try Reader.fetchCursor(db)
                let names = cursor.map { $0.name }
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
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
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(reader.id!, arthur.id!)
                XCTAssertEqual(reader.name, arthur.name)
                XCTAssertEqual(reader.age, arthur.age)
            }
            
            do {
                let names = try AltReader.fetchCursor(db, request).map { $0.name }
                XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                XCTAssertEqual(try names.next()!, arthur.name)
                XCTAssertEqual(try names.next()!, barbara.name)
                XCTAssertTrue(try names.next() == nil)
            }
        }
    }
}
