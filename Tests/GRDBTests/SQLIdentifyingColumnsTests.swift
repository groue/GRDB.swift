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
            
            try XCTAssertEqual((alias[Column("a")] == 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] === 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == nil)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((1 == alias[Column("a")])._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[SQLExpressionFastPrimaryKey()] == 1)._identifyingColums(db, for: alias), ["id"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("a")] == 2)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] == 1)._identifyingColums(db, for: alias), ["a", "b"])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] > 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((otherAlias[Column("a")] == 1 && alias[Column("b")] == 1)._identifyingColums(db, for: alias), ["b"])
            
            try XCTAssertEqual((otherAlias[Column("a")])._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == 1 || alias[Column("a")] == 2)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == alias[Column("b")])._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] > 1)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] != 1)._identifyingColums(db, for: alias), [])
        }
    }
}
