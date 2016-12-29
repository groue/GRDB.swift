import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

private struct Person : RowConvertible, TableMapping {
    static let databaseTableName = "persons"
    init(row: Row) {
    }
}

class RecordUniqueIndexTests: GRDBTestCase {

    func testFetchOneRequiresUniqueIndex() {
        assertNoError { db in
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
                
                _ = try Person.makeFetchByKeyStatement(db, keys: [["id": nil]])
                _ = try Person.makeFetchByKeyStatement(db, keys: [["email": nil]])
                do {
                    _ = try Person.makeFetchByKeyStatement(db, keys: [["id": nil, "email": nil]], fatalErrorOnMissingUniqueIndex: false)
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "table persons has no unique index on column(s) id, email")
                    XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) id, email")
                }
                do {
                    _ = try Person.makeFetchByKeyStatement(db, keys: [["name": nil]], fatalErrorOnMissingUniqueIndex: false)
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "table persons has no unique index on column(s) name")
                    XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) name")
                }
            }
        }
    }
    
    func testDeleteOneRequiresUniqueIndex() {
        assertNoError { db in
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
                
                _ = try Person.makeDeleteByKeyStatement(db, keys: [["id": nil]])
                _ = try Person.makeDeleteByKeyStatement(db, keys: [["email": nil]])
                do {
                    _ = try Person.makeDeleteByKeyStatement(db, keys: [["id": nil, "email": nil]], fatalErrorOnMissingUniqueIndex: false)
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "table persons has no unique index on column(s) id, email")
                    XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) id, email")
                }
                do {
                    _ = try Person.makeDeleteByKeyStatement(db, keys: [["name": nil]], fatalErrorOnMissingUniqueIndex: false)
                    XCTFail()
                } catch let error as DatabaseError {
                    XCTAssertEqual(error.code, 21) // SQLITE_MISUSE
                    XCTAssertEqual(error.message!, "table persons has no unique index on column(s) name")
                    XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) name")
                }
            }
        }
    }
}
