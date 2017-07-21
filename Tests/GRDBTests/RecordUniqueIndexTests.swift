import XCTest
#if GRDBCIPHER
    @testable import GRDBCipher
#elseif GRDBCUSTOMSQLITE
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
    
    func testKeyFilterRequiresUniqueIndex() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
            
            _ = try Person.filter(db, keys: [["id": nil]])
            _ = try Person.filter(db, keys: [["email": nil]])
            do {
                _ = try Person.filter(db, keys: [["id": nil, "email": nil]], fatalErrorOnMissingUniqueIndex: false)
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, "table persons has no unique index on column(s) email, id")
                XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) email, id")
            }
            do {
                _ = try Person.filter(db, keys: [["name": nil]], fatalErrorOnMissingUniqueIndex: false)
                XCTFail()
            } catch let error as DatabaseError {
                XCTAssertEqual(error.resultCode, .SQLITE_MISUSE)
                XCTAssertEqual(error.message!, "table persons has no unique index on column(s) name")
                XCTAssertEqual(error.description, "SQLite error 21: table persons has no unique index on column(s) name")
            }
        }
    }
}
