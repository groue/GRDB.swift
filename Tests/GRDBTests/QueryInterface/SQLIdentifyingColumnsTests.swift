import XCTest
@testable import GRDB

class SQLIdentifyingColumnsTests: GRDBTestCase {
    func testIdentifyingColumns() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { t in
                t.autoIncrementedPrimaryKey("id")
            }
            let alias = TableAlias(tableName: "t")
            let otherAlias = TableAlias()
            
            try XCTAssertEqual((alias[Column("a")] == 1).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] === 1).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == nil).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((1 == alias[Column("a")]).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((alias[SQLExpression.fastPrimaryKey] == 1).identifyingColumns(db, for: alias), ["id"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("a")] == 2).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] == 1).identifyingColumns(db, for: alias), ["a", "b"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] > 1).identifyingColumns(db, for: alias), ["a"])
            try XCTAssertEqual((otherAlias[Column("a")] == 1 && alias[Column("b")] == 1).identifyingColumns(db, for: alias), ["b"])
            
            try XCTAssertEqual((otherAlias[Column("a")]).identifyingColumns(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == 1 || alias[Column("a")] == 2).identifyingColumns(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == alias[Column("b")]).identifyingColumns(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] > 1).identifyingColumns(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] != 1).identifyingColumns(db, for: alias), [])
        }
    }
}
