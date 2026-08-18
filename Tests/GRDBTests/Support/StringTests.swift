import XCTest
import GRDB

final class StringTests: GRDBTestCase {
    
    // A string that contains a NUL character. SQLite supports those
    // strings: https://sqlite.org/nulinstr.html
    private let nulString = "foo\u{0}bar"
    
    func testStringDatabaseRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func roundTrip(_ value: String) throws -> Bool {
                guard let back = try String.fetchOne(db, sql: "SELECT ?", arguments: [value]) else {
                    XCTFail("Failed to fetch a String")
                    return false
                }
                return back == value
            }
            
            XCTAssertTrue(try roundTrip(""))
            XCTAssertTrue(try roundTrip("foo"))
            XCTAssertTrue(try roundTrip("'fooéı👨👨🏿🇫🇷🇨🇮'"))
            XCTAssertTrue(try roundTrip(nulString))
        }
    }
    
    func testStringDatabaseValueRoundTrip() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            func roundTrip(_ value: String) throws -> Bool {
                let row = try Row.fetchOne(db, sql: "SELECT ?", arguments: [value])!
                guard let back = String.fromDatabaseValue(row[0]) else {
                    XCTFail("Failed to convert from DatabaseValue to String")
                    return false
                }
                return back == value
            }
            
            XCTAssertTrue(try roundTrip(""))
            XCTAssertTrue(try roundTrip("foo"))
            XCTAssertTrue(try roundTrip("'fooéı👨👨🏿🇫🇷🇨🇮'"))
            XCTAssertTrue(try roundTrip(nulString))
        }
    }
    
    // Statements execute with temporary bindings, and do not copy their
    // string arguments. See `String.withBinding(to:at:do:)`.
    func testStringWithTemporaryBinding() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (value TEXT)")
            try db.execute(sql: "INSERT INTO t VALUES (?)", arguments: [nulString])
            
            let fetched = try String.fetchOne(db, sql: "SELECT value FROM t")
            XCTAssertEqual(fetched, nulString)
        }
    }
    
    // Statements that are given their arguments before execution copy their
    // string arguments. See `String.bind(to:at:)`.
    func testStringWithStatementArguments() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.inDatabase { db in
            try db.execute(sql: "CREATE TABLE t (value TEXT)")
            let statement = try db.makeStatement(sql: "INSERT INTO t VALUES (?)")
            statement.arguments = [nulString]
            try statement.execute()
            
            let fetched = try String.fetchOne(db, sql: "SELECT value FROM t")
            XCTAssertEqual(fetched, nulString)
        }
    }
}
