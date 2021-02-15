import XCTest

@testable import GRDB

class DatabaseValueConvertibleEscapingTests: GRDBTestCase {
    
    func testNull() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(DatabaseValue.null.sqlExpression.quotedSQL(db), "NULL")
        }
    }
    
    func testText() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual("".sqlExpression.quotedSQL(db), "''")
            try XCTAssertEqual("foo".sqlExpression.quotedSQL(db), "'foo'")
            try XCTAssertEqual("\"foo\"".sqlExpression.quotedSQL(db), #"'"foo"'"#)
            try XCTAssertEqual("'foo'".sqlExpression.quotedSQL(db), "'''foo'''")
        }
    }
    
    func testInteger() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(0.sqlExpression.quotedSQL(db), "0")
            try XCTAssertEqual(Int64.min.sqlExpression.quotedSQL(db), "-9223372036854775808")
            try XCTAssertEqual(Int64.max.sqlExpression.quotedSQL(db), "9223372036854775807")
        }
    }
    
    func testDouble() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(0.0.sqlExpression.quotedSQL(db), "0.0")
            try XCTAssertEqual(1.0.sqlExpression.quotedSQL(db), "1.0")
            try XCTAssertEqual((-1.0).sqlExpression.quotedSQL(db), "-1.0")
            try XCTAssertEqual(1.5.sqlExpression.quotedSQL(db), "1.5")
        }
    }
    
    func testBlob() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual(Data().sqlExpression.quotedSQL(db), "X''")
            try XCTAssertEqual("foo".data(using: .utf8)!.sqlExpression.quotedSQL(db), "X'666F6F'")
        }
    }
    
    func testComplexExpression() throws {
        try makeDatabaseQueue().inDatabase { db in
            try XCTAssertEqual((Column("a") == 12).quotedSQL(db), #""a" = 12"#)
        }
    }
}
