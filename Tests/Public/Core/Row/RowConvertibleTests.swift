import XCTest
#if USING_SQLCIPHER
    import GRDBCipher
#elseif USING_CUSTOMSQLITE
    import GRDBCustomSQLite
#else
    import GRDB
#endif

private struct SimpleRowConvertible {
    var firstName: String
    var lastName: String
    var fetched: Bool = false
}

extension SimpleRowConvertible : RowConvertible {
    init(row: Row) {
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        fetched = false
    }
    
    mutating func awakeFromFetch(row: Row) {
        fetched = true
    }
}

private class Person : RowConvertible {
    var firstName: String
    var lastName: String
    var bestFriend: Person?
    var fetched: Bool = false

    required init(row: Row) {
        firstName = row.value(named: "firstName")
        lastName = row.value(named: "lastName")
        if let bestFriendRow = row.scoped(on: "bestFriend") {
            bestFriend = Person(row: bestFriendRow)
        }
        fetched = false
    }
    
    func awakeFromFetch(row: Row) {
        fetched = true
        if let bestFriend = bestFriend, let bestFriendRow = row.scoped(on: "bestFriend") {
            bestFriend.awakeFromFetch(row: bestFriendRow)
        }
    }
}

class RowConvertibleTests: GRDBTestCase {

    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.execute("CREATE TABLE structs (firstName TEXT, lastName TEXT)")
        }
    }
    
    func testRowInitializer() {
        let row = Row(["firstName": "Arthur", "lastName": "Martin"])
        let s = SimpleRowConvertible(row: row)
        XCTAssertEqual(s.firstName, "Arthur")
        XCTAssertEqual(s.lastName, "Martin")
        XCTAssertFalse(s.fetched)
    }
    
    func testFetchCursorFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let statement = try db.makeSelectStatement("SELECT * FROM structs")
                let cursor = try SimpleRowConvertible.fetchCursor(statement)
                let s = try cursor.next()!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchCursorFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let statement = try db.makeSelectStatement(sql)
                let cursor = try Person.fetchCursor(statement, arguments: arguments, adapter: adapter)
                let s = try cursor.next()!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchAllFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let statement = try db.makeSelectStatement("SELECT * FROM structs")
                let ss = SimpleRowConvertible.fetchAll(statement)
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchAllFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let statement = try db.makeSelectStatement(sql)
                let ss = Person.fetchAll(statement, arguments: arguments, adapter: adapter)
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchOneFromStatement() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let statement = try db.makeSelectStatement("SELECT * FROM structs")
                let missingS = SimpleRowConvertible.fetchOne(statement)
                XCTAssertTrue(missingS == nil)
                
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let s = SimpleRowConvertible.fetchOne(statement)!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchOneFromStatementWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let statement = try db.makeSelectStatement(sql)
                let s = Person.fetchOne(statement, arguments: arguments, adapter: adapter)!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchCursorFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let cursor = try SimpleRowConvertible.fetchCursor(db, "SELECT * FROM structs")
                let s = try cursor.next()!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchCursorFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let cursor = try Person.fetchCursor(db, sql, arguments: arguments, adapter: adapter)
                let s = try cursor.next()!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchAllFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let ss = SimpleRowConvertible.fetchAll(db, "SELECT * FROM structs")
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchAllFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let ss = Person.fetchAll(db, sql, arguments: arguments, adapter: adapter)
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchOneFromSQL() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                let missingS = SimpleRowConvertible.fetchOne(db, "SELECT * FROM structs")
                XCTAssertTrue(missingS == nil)
                
                try db.execute("INSERT INTO structs (firstName, lastName) VALUES (?, ?)", arguments: ["Arthur", "Martin"])
                let s = SimpleRowConvertible.fetchOne(db, "SELECT * FROM structs")!
                XCTAssertEqual(s.firstName, "Arthur")
                XCTAssertEqual(s.lastName, "Martin")
                XCTAssertTrue(s.fetched)
            }
        }
    }
    
    func testFetchOneFromSQLWithAdapter() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                    .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                let s = Person.fetchOne(db, sql, arguments: arguments, adapter: adapter)!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchCursorFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                            .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                        let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                        let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                        
                        let statement = try db.makeSelectStatement(sql)
                        statement.arguments = arguments
                        return (statement, adapter)
                    }
                }
                let cursor = try Person.fetchCursor(db, Request())
                let s = try cursor.next()!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
    
    func testFetchAllFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                            .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                        let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                        let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])
                        
                        let statement = try db.makeSelectStatement(sql)
                        statement.arguments = arguments
                        return (statement, adapter)
                    }
                }
                let ss = Person.fetchAll(db, Request())
                let s = ss.first!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }

    func testFetchOneFromFetchRequest() {
        assertNoError {
            let dbQueue = try makeDatabaseQueue()
            dbQueue.inDatabase { db in
                struct Request : FetchRequest {
                    func prepare(_ db: Database) throws -> (SelectStatement, RowAdapter?) {
                        let adapter = ColumnMapping(["firstName": "firstName1", "lastName": "lastName1"])
                            .addingScopes(["bestFriend": ColumnMapping(["firstName": "firstName2", "lastName": "lastName2"])])
                        let sql = "SELECT ? AS firstName1, ? AS lastName1, ? AS firstName2, ? AS lastName2"
                        let arguments = StatementArguments(["Stan", "Laurel", "Oliver", "Hardy"])

                        let statement = try db.makeSelectStatement(sql)
                        statement.arguments = arguments
                        return (statement, adapter)
                    }
                }
                let s = Person.fetchOne(db, Request())!
                XCTAssertEqual(s.firstName, "Stan")
                XCTAssertEqual(s.lastName, "Laurel")
                XCTAssertTrue(s.fetched)
                XCTAssertEqual(s.bestFriend!.firstName, "Oliver")
                XCTAssertEqual(s.bestFriend!.lastName, "Hardy")
                XCTAssertTrue(s.bestFriend!.fetched)
            }
        }
    }
}
