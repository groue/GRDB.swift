import XCTest

@testable import GRDB

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {
    
    func testNull() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(DatabaseValue.null.quotedSQL(db), "NULL")
        }
    }
    
    func testText() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual("".databaseValue.quotedSQL(db), "''")
            try XCTAssertEqual("foo".databaseValue.quotedSQL(db), "'foo'")
            try XCTAssertEqual("\"foo\"".databaseValue.quotedSQL(db), #"'"foo"'"#)
            try XCTAssertEqual("'foo'".databaseValue.quotedSQL(db), "'''foo'''")
        }
    }
    
    func testInteger() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(0.databaseValue.quotedSQL(db), "0")
            try XCTAssertEqual(Int64.min.databaseValue.quotedSQL(db), "-9223372036854775808")
            try XCTAssertEqual(Int64.max.databaseValue.quotedSQL(db), "9223372036854775807")
        }
    }
    
    func testDouble() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(0.0.databaseValue.quotedSQL(db), "0.0")
            try XCTAssertEqual(1.0.databaseValue.quotedSQL(db), "1.0")
            try XCTAssertEqual((-1.0).databaseValue.quotedSQL(db), "-1.0")
            try XCTAssertEqual(1.5.databaseValue.quotedSQL(db), "1.5")
        }
    }
    
    func testBlob() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(Data().databaseValue.quotedSQL(db), "X''")
            try XCTAssertEqual("foo".data(using: .utf8)!.databaseValue.quotedSQL(db), "X'666F6F'")
        }
    }
    
    func testComplexExpression() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual((Column("a") == 12).quotedSQL(db), #""a" = 12"#)
        }
    }
}
