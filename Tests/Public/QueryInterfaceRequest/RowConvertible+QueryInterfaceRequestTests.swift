import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
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
        id = row.value(named: "id")
        name = row.value(named: "name")
        age = row.value(named: "age")
    }
}

extension Reader : MutablePersistable {
    static let databaseTableName = "readers"
    
    var persistentDictionary: [String: DatabaseValueConvertible?] {
        return ["id": id, "name": name, "age": age]
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
        id = row.value(named: "id")
        name = row.value(named: "name")
        age = row.value(named: "age")
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
    
    func testAll() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var arthur = Reader(id: nil, name: "Arthur", age: 42)
                try arthur.insert(db)
                var barbara = Reader(id: nil, name: "Barbara", age: 36)
                try barbara.insert(db)
                
                let request = Reader.all()
                
                do {
                    let readers = request.fetchAll(db)
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
                    let reader = request.fetchOne(db)!
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(reader.id!, arthur.id!)
                    XCTAssertEqual(reader.name, arthur.name)
                    XCTAssertEqual(reader.age, arthur.age)
                }
                
                do {
                    let names = request.fetch(db).map { $0.name }
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(names, [arthur.name, barbara.name])
                }
            }
        }
    }
    
    func testFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var arthur = Reader(id: nil, name: "Arthur", age: 42)
                try arthur.insert(db)
                var barbara = Reader(id: nil, name: "Barbara", age: 36)
                try barbara.insert(db)
                
                do {
                    let readers = Reader.fetchAll(db)
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
                    let reader = Reader.fetchOne(db)!
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(reader.id!, arthur.id!)
                    XCTAssertEqual(reader.name, arthur.name)
                    XCTAssertEqual(reader.age, arthur.age)
                }
                
                do {
                    let names = Reader.fetch(db).map { $0.name }
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(names, [arthur.name, barbara.name])
                }
            }
        }
    }
    
    func testAlternativeFetch() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                var arthur = Reader(id: nil, name: "Arthur", age: 42)
                try arthur.insert(db)
                var barbara = Reader(id: nil, name: "Barbara", age: 36)
                try barbara.insert(db)
                
                let request = Reader.all()
                
                do {
                    let readers = AltReader.fetchAll(db, request)
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
                    let reader = AltReader.fetchOne(db, request)!
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(reader.id!, arthur.id!)
                    XCTAssertEqual(reader.name, arthur.name)
                    XCTAssertEqual(reader.age, arthur.age)
                }
                
                do {
                    let names = AltReader.fetch(db, request).map { $0.name }
                    XCTAssertEqual(lastSQLQuery, "SELECT * FROM \"readers\"")
                    XCTAssertEqual(names, [arthur.name, barbara.name])
                }
            }
        }
    }
}
