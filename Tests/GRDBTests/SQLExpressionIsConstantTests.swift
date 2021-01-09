import XCTest
@testable import GRDB

// Column
// DatabaseValue
// SQLExpressionAssociativeBinary
// SQLExpressionBetween
// SQLExpressionBinary
// SQLExpressionCollate
// SQLExpressionContains
// SQLExpressionCount
// SQLExpressionCountDistinct
// SQLExpressionEqual
// SQLExpressionFastPrimaryKey
// SQLExpressionFunction
// SQLExpressionIsEmpty
// SQLExpressionLiteral
// SQLExpressionNot
// SQLExpressionQualifiedFastPrimaryKey
// SQLExpressionTableMatch
// SQLExpressionUnary
// SQLQualifiedColumn
// SQLRowValue
class SQLExpressionIsConstantTests: GRDBTestCase {
    func testColumn() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            try XCTAssertEqual(Column("a")._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(Column("a")._column(db, for: alias, acceptsBijection: false), nil)

            // DatabaseValue
            try XCTAssertEqual("foo".databaseValue._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual("foo".databaseValue._column(db, for: alias, acceptsBijection: false), nil)

            // SQLExpressionAssociativeBinary
            try XCTAssertEqual([].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([Column("a")].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([Column("a")].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([alias[Column("a")]].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual([alias[Column("a")]].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual([-alias[Column("a")]].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual([-alias[Column("a")]].joined(operator: .multiply)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] * "foo".databaseValue)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] * "foo".databaseValue)._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue)._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual((alias[Column("a")] + alias[Column("b")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + alias[Column("b")])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([alias[Column("a")], "foo".databaseValue].joined(operator: .concat)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([alias[Column("a")], "foo".databaseValue].joined(operator: .concat)._column(db, for: alias, acceptsBijection: true), "a")
            
            // SQLExpressionBetween
            try XCTAssertEqual((1...3).contains(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((1...3).contains(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            
            // SQLExpressionBinary
            try XCTAssertEqual((alias[Column("a")] - "foo".databaseValue)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] - "foo".databaseValue)._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual((alias[Column("a")] - alias[Column("b")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] - alias[Column("b")])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] < "foo".databaseValue)._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] < "foo".databaseValue)._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCollate
            try XCTAssertEqual(Column("a").collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(Column("a").collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(alias[Column("a")].collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(alias[Column("a")].collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).collating(.binary).sqlExpression._column(db, for: alias, acceptsBijection: true), "a")

            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCount
            try XCTAssertEqual(count(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(count(alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCountDistinct
            try XCTAssertEqual(count(distinct: alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(count(distinct: alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionEqual
            try XCTAssertEqual((alias[Column("a")] == "foo")._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] == "foo")._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionFastPrimaryKey
            try XCTAssertEqual(SQLExpressionFastPrimaryKey()._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpressionFastPrimaryKey()._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionFunction
            try XCTAssertEqual(length(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(length(alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] ?? "foo")._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] ?? "foo")._column(db, for: alias, acceptsBijection: true), "a")

            // SQLExpressionIsEmpty
            try XCTAssertEqual(SQLExpressionIsEmpty(alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpressionIsEmpty(alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionLiteral
            try XCTAssertEqual(SQLLiteral("\(alias[Column("a")]) * 2").sqlExpression._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLLiteral("\(alias[Column("a")]) * 2").sqlExpression._column(db, for: alias, acceptsBijection: true), nil)

            // SQLExpressionNot
            try XCTAssertEqual((!alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((!alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionQualifiedFastPrimaryKey
            try XCTAssertEqual(alias[SQLExpressionFastPrimaryKey()]._column(db, for: alias, acceptsBijection: false), "id")
            try XCTAssertEqual(alias[SQLExpressionFastPrimaryKey()]._column(db, for: alias, acceptsBijection: true), "id")
            
            // SQLExpressionTableMatch
            try XCTAssertEqual(SQLExpressionTableMatch(alias: alias, pattern: alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpressionTableMatch(alias: alias, pattern: alias[Column("a")])._column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionUnary
            try XCTAssertEqual((-Column("a"))._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((-Column("a"))._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((-alias[Column("a")])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((-alias[Column("a")])._column(db, for: alias, acceptsBijection: true), "a")
            
            // SQLQualifiedColumn
            try XCTAssertEqual(alias[Column("a")]._column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(alias[Column("a")]._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(TableAlias()[Column("a")]._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(TableAlias()[Column("a")]._column(db, for: alias, acceptsBijection: true), nil)

            // SQLRowValue
            try XCTAssertEqual(SQLRowValue([1.databaseValue])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([1.databaseValue])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLRowValue([alias[Column("a")]])._column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(SQLRowValue([alias[Column("a")]])._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(SQLRowValue([-alias[Column("a")]])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([-alias[Column("a")]])._column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(SQLRowValue([1.databaseValue, 2.databaseValue])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([1.databaseValue, 2.databaseValue])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLRowValue([alias[Column("a")], 2.databaseValue])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([alias[Column("a")], 2.databaseValue])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLRowValue([1.databaseValue, alias[Column("a")]])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([1.databaseValue, alias[Column("a")]])._column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLRowValue([alias[Column("a")], alias[Column("a")]])._column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLRowValue([alias[Column("a")], alias[Column("a")]])._column(db, for: alias, acceptsBijection: true), nil)
        }
    }
    
    func testIdentifyingColumns() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            try XCTAssertEqual(Column("a")._identifyingColums(db, for: alias), [])
            
            // DatabaseValue
            try XCTAssertEqual("foo".databaseValue._identifyingColums(db, for: alias), [])
            
            // SQLExpressionAssociativeBinary
            try XCTAssertEqual((alias[Column("a")] == 1 || alias[Column("b")] == 2)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] == 2)._identifyingColums(db, for: alias), ["a", "b"])
            try XCTAssertEqual((alias[Column("a")] == 1 && TableAlias()[Column("b")] == 2)._identifyingColums(db, for: alias), ["a"])
            
            // SQLExpressionBetween
            try XCTAssertEqual((1...3).contains(alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionBinary
            try XCTAssertEqual((alias[Column("a")] - 1)._identifyingColums(db, for: alias), [])
            
            // SQLExpressionCollate
            try XCTAssertEqual((alias[Column("a")] == 1).collating(.binary).sqlExpression._identifyingColums(db, for: alias), ["a"])
            
            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionCount
            try XCTAssertEqual(count(alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionCountDistinct
            try XCTAssertEqual(count(distinct: alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionEqual
            try XCTAssertEqual((alias[Column("a")] == nil)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((1 == alias[Column("a")])._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((-alias[Column("a")] == 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual(((alias[Column("a")] * 2) == 1)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual(((alias[Column("a")] + 2) == 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual(((alias[Column("a")] - 2) == 1)._identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[SQLExpressionFastPrimaryKey()] == 1)._identifyingColums(db, for: alias), ["id"])
            try XCTAssertEqual((alias[Column("a")] == alias[Column("b")])._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((TableAlias()[Column("a")] == nil)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((TableAlias()[Column("a")] == 1)._identifyingColums(db, for: alias), [])
            try XCTAssertEqual((SQLRowValue([alias[SQLExpressionFastPrimaryKey()]]) == 1)._identifyingColums(db, for: alias), ["id"])
            
            // SQLExpressionFastPrimaryKey
            try XCTAssertEqual(SQLExpressionFastPrimaryKey()._identifyingColums(db, for: alias), [])
            
            // SQLExpressionFunction
            try XCTAssertEqual(length(alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionIsEmpty
            try XCTAssertEqual(SQLExpressionIsEmpty(alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionLiteral
            // SQLExpressionNot
            try XCTAssertEqual((!alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLExpressionQualifiedFastPrimaryKey
            try XCTAssertEqual(alias[SQLExpressionFastPrimaryKey()]._identifyingColums(db, for: alias), [])
            
            // SQLExpressionTableMatch
            // SQLExpressionUnary
            try XCTAssertEqual((-alias[Column("a")])._identifyingColums(db, for: alias), [])
            
            // SQLQualifiedColumn
            try XCTAssertEqual(alias[Column("a")]._identifyingColums(db, for: alias), [])
            
            // SQLRowValue
            try XCTAssertEqual(SQLRowValue([alias[SQLExpressionFastPrimaryKey()]])._identifyingColums(db, for: alias), [])
            try XCTAssertEqual(SQLRowValue([alias[SQLExpressionFastPrimaryKey()] == 1])._identifyingColums(db, for: alias), ["id"])
        }
    }
    
    func testIdentifyingRowIDs() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            // DatabaseValue
            // SQLExpressionAssociativeBinary
            try XCTAssertEqual((alias[Column("id")] == 1 || alias[Column("id")] == 3)._identifyingRowIDs(db, for: alias), [1, 3])
            try XCTAssertEqual((alias[Column("id")] == 1 && alias[Column("id")] == 3)._identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual((alias[Column("id")] == 1 && alias[Column("id")] == 1)._identifyingRowIDs(db, for: alias), [1])
            
            // SQLExpressionBetween
            try XCTAssertEqual((0...Int.max).contains(TableAlias()[Column("id")])._identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionBinary
            // SQLExpressionCollate
            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(TableAlias()[Column("id")])._identifyingRowIDs(db, for: alias), nil)
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("id")])._identifyingRowIDs(db, for: alias), [1, 2, 3])
            try XCTAssertEqual([].contains(alias[Column("id")])._identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("id")] + 1)._identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionCount
            // SQLExpressionCountDistinct
            // SQLExpressionEqual
            try XCTAssertEqual((TableAlias()[Column("id")] == 1)._identifyingRowIDs(db, for: alias), nil)
            try XCTAssertEqual((alias[Column("id")] == 1)._identifyingRowIDs(db, for: alias), [1])
            try XCTAssertEqual((alias[Column("id")] == nil)._identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual(((alias[Column("id")] + 1) == 2)._identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionFastPrimaryKey
            // SQLExpressionFunction
            // SQLExpressionIsEmpty
            // SQLExpressionLiteral
            // SQLExpressionNot
            // SQLExpressionQualifiedFastPrimaryKey
            // SQLExpressionTableMatch
            // SQLExpressionUnary
            // SQLQualifiedColumn
            // SQLRowValue
        }
    }

    func testIsConstantInRequest() {
        // Column
        XCTAssertFalse(Column("a")._isConstantInRequest)
        
        // DatabaseValue
        XCTAssertTrue(1.databaseValue._isConstantInRequest)
        
        // SQLExpressionAssociativeBinary
        XCTAssertTrue([].joined(operator: .multiply)._isConstantInRequest)
        XCTAssertTrue([1.databaseValue].joined(operator: .multiply)._isConstantInRequest)
        XCTAssertFalse([Column("a")].joined(operator: .multiply)._isConstantInRequest)
        XCTAssertTrue([1.databaseValue, 2.databaseValue].joined(operator: .multiply)._isConstantInRequest)
        XCTAssertFalse([Column("a"), 2.databaseValue].joined(operator: .multiply)._isConstantInRequest)
        XCTAssertFalse([1.databaseValue, Column("a")].joined(operator: .multiply)._isConstantInRequest)
        
        // SQLExpressionBetween
        XCTAssertTrue((1...3).contains(1.databaseValue)._isConstantInRequest)
        XCTAssertFalse((1...3).contains(Column("a"))._isConstantInRequest)
        
        // SQLExpressionBinary
        XCTAssertTrue((1.databaseValue - 2.databaseValue)._isConstantInRequest)
        XCTAssertFalse((Column("a") - 2.databaseValue)._isConstantInRequest)
        XCTAssertFalse((1.databaseValue - Column("a"))._isConstantInRequest)
        
        // SQLExpressionCollate
        XCTAssertTrue("foo".databaseValue.collating(.binary).sqlExpression._isConstantInRequest)
        XCTAssertFalse(Column("a").collating(.binary).sqlExpression._isConstantInRequest)
        
        // SQLExpressionContains
        XCTAssertFalse([1, 2, 3].contains(Column("a"))._isConstantInRequest)
        
        // SQLExpressionCount
        XCTAssertFalse(count(Column("a"))._isConstantInRequest)
        
        // SQLExpressionCountDistinct
        XCTAssertFalse(count(distinct: Column("a"))._isConstantInRequest)
        
        // SQLExpressionEqual
        XCTAssertTrue((1.databaseValue == 2.databaseValue)._isConstantInRequest)
        XCTAssertFalse((Column("a") == 2.databaseValue)._isConstantInRequest)
        XCTAssertFalse((1.databaseValue == Column("a"))._isConstantInRequest)
        
        // SQLExpressionFastPrimaryKey
        XCTAssertFalse(SQLExpressionFastPrimaryKey()._isConstantInRequest)
        
        // SQLExpressionFunction
        XCTAssertTrue(length("foo".databaseValue)._isConstantInRequest)
        XCTAssertFalse(length(Column("a"))._isConstantInRequest)
        
        // SQLExpressionIsEmpty
        XCTAssertTrue(SQLExpressionIsEmpty("foo".databaseValue)._isConstantInRequest)
        XCTAssertFalse(SQLExpressionIsEmpty(Column("a"))._isConstantInRequest)

        // SQLExpressionLiteral
        XCTAssertFalse(SQLLiteral("1").sqlExpression._isConstantInRequest)
        
        // SQLExpressionNot
        XCTAssertTrue((!(true.databaseValue))._isConstantInRequest)
        XCTAssertFalse((!Column("a"))._isConstantInRequest)
        
        // SQLExpressionQualifiedFastPrimaryKey
        XCTAssertFalse(SQLExpressionFastPrimaryKey()._qualifiedExpression(with: TableAlias())._isConstantInRequest)
        
        // SQLExpressionTableMatch
        XCTAssertFalse(SQLExpressionTableMatch(alias: TableAlias(), pattern: "foo".databaseValue)._isConstantInRequest)
        
        // SQLExpressionUnary
        XCTAssertTrue((-(1.databaseValue))._isConstantInRequest)
        XCTAssertFalse((-Column("a"))._isConstantInRequest)
        
        // SQLQualifiedColumn
        XCTAssertFalse(Column("a")._qualifiedExpression(with: TableAlias())._isConstantInRequest)
        
        // SQLRowValue
        XCTAssertTrue(SQLRowValue([1.databaseValue])._isConstantInRequest)
        XCTAssertFalse(SQLRowValue([Column("a")])._isConstantInRequest)
        XCTAssertTrue(SQLRowValue([1.databaseValue, 2.databaseValue])._isConstantInRequest)
        XCTAssertFalse(SQLRowValue([Column("a"), 2.databaseValue])._isConstantInRequest)
        XCTAssertFalse(SQLRowValue([1.databaseValue, Column("a")])._isConstantInRequest)
    }
}
