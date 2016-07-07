import XCTest
#if USING_SQLCIPHER
    @testable import GRDBCipher
#elseif USING_CUSTOMSQLITE
    @testable import GRDBCustomSQLite
#else
    @testable import GRDB
#endif

private struct Person : RowConvertible, TableMapping {
    static func databaseTableName() -> String {
        return "persons"
    }
    init(row: Row) {
    }
}

private struct Citizenship : RowConvertible, TableMapping {
    static func databaseTableName() -> String {
        return "citizenships"
    }
    init(row: Row) {
    }
}

class UniqueIndexTests: GRDBTestCase {
    
    func testColumnsThatUniquelyIdentityRows() {
        assertNoError { db in
            let dbQueue = try makeDatabaseQueue()
            try dbQueue.inDatabase { db in
                try db.execute("CREATE TABLE persons (id INTEGER PRIMARY KEY, name TEXT, email TEXT UNIQUE)")
                try XCTAssertTrue(db.columns(["id"], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertTrue(db.columns(["email"], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertFalse(db.columns([], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertFalse(db.columns(["name"], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertFalse(db.columns(["id", "email"], uniquelyIdentifyRowsIn: "persons"))

                try db.execute("CREATE TABLE citizenships (personId INTEGER NOT NULL, countryIsoCode TEXT NOT NULL, PRIMARY KEY (personId, countryIsoCode))")
                try XCTAssertTrue(db.columns(["personId", "countryIsoCode"], uniquelyIdentifyRowsIn: "citizenships"))
                try XCTAssertTrue(db.columns(["countryIsoCode", "personId"], uniquelyIdentifyRowsIn: "citizenships"))
                try XCTAssertFalse(db.columns([], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertFalse(db.columns(["personId"], uniquelyIdentifyRowsIn: "persons"))
                try XCTAssertFalse(db.columns(["countryIsoCode"], uniquelyIdentifyRowsIn: "persons"))
            }
        }
    }

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
