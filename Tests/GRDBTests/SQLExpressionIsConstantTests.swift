import XCTest
@testable import GRDB

class SQLExpressionIsConstantTests: GRDBTestCase {
    func testColumn() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            try XCTAssertEqual(Column("a").sqlExpression.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(Column("a").sqlExpression.column(db, for: alias, acceptsBijection: false), nil)

            // DatabaseValue
            try XCTAssertEqual("foo".sqlExpression.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual("foo".sqlExpression.column(db, for: alias, acceptsBijection: false), nil)

            // SQLExpressionAssociativeBinary
            try XCTAssertEqual([].joined(operator: .multiply).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([].joined(operator: .multiply).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([Column("a")].joined(operator: .multiply).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([Column("a")].joined(operator: .multiply).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([alias[Column("a")]].joined(operator: .multiply).column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual([alias[Column("a")]].joined(operator: .multiply).column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual([-alias[Column("a")]].joined(operator: .multiply).column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual([-alias[Column("a")]].joined(operator: .multiply).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] * "foo".databaseValue).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] * "foo".databaseValue).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] + alias[Column("b")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + alias[Column("b")]).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual([alias[Column("a")], "foo".databaseValue].joined(operator: .concat).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([alias[Column("a")], "foo".databaseValue].joined(operator: .concat).column(db, for: alias, acceptsBijection: true), "a")
            
            // SQLExpressionBetween
            try XCTAssertEqual((1...3).contains(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((1...3).contains(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            
            // SQLExpressionBinary
            try XCTAssertEqual((alias[Column("a")] - "foo".databaseValue).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] - "foo".databaseValue).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] - alias[Column("b")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] - alias[Column("b")]).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] < "foo".databaseValue).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] < "foo".databaseValue).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCollate
            try XCTAssertEqual(Column("a").collating(.binary).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(Column("a").collating(.binary).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(alias[Column("a")].collating(.binary).column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(alias[Column("a")].collating(.binary).column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).collating(.binary).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] + "foo".databaseValue).collating(.binary).column(db, for: alias, acceptsBijection: true), nil)

            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCount
            try XCTAssertEqual(count(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(count(alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionCountDistinct
            try XCTAssertEqual(count(distinct: alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(count(distinct: alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionEqual
            try XCTAssertEqual((alias[Column("a")] == "foo").column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] == "foo").column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionFastPrimaryKey
            try XCTAssertEqual(SQLExpression.fastPrimaryKey.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.fastPrimaryKey.column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionFunction
            try XCTAssertEqual(length(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(length(alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((alias[Column("a")] ?? "foo").column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((alias[Column("a")] ?? "foo").column(db, for: alias, acceptsBijection: true), "a")

            // SQLExpression.isEmpty
            try XCTAssertEqual(SQLExpression.isEmpty(alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.isEmpty(alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionLiteral
            try XCTAssertEqual(SQL("\(alias[Column("a")]) * 2").sqlExpression.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQL("\(alias[Column("a")]) * 2").sqlExpression.column(db, for: alias, acceptsBijection: true), nil)

            // SQLExpressionNot
            try XCTAssertEqual((!alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((!alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionQualifiedFastPrimaryKey
            try XCTAssertEqual(alias[SQLExpression.fastPrimaryKey].column(db, for: alias, acceptsBijection: false), "id")
            try XCTAssertEqual(alias[SQLExpression.fastPrimaryKey].column(db, for: alias, acceptsBijection: true), "id")
            
            // SQLExpression.tableMatch
            try XCTAssertEqual(SQLExpression.tableMatch(alias, alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.tableMatch(alias, alias[Column("a")]).column(db, for: alias, acceptsBijection: true), nil)
            
            // SQLExpressionUnary
            try XCTAssertEqual((-Column("a")).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((-Column("a")).column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual((-alias[Column("a")]).column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual((-alias[Column("a")]).column(db, for: alias, acceptsBijection: true), "a")
            
            // SQLQualifiedColumn
            try XCTAssertEqual(alias[Column("a")].column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(alias[Column("a")].column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(TableAlias()[Column("a")].column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(TableAlias()[Column("a")].column(db, for: alias, acceptsBijection: true), nil)

            // SQLExpression.rowValue
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression])!.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")]])!.column(db, for: alias, acceptsBijection: false), "a")
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")]])!.column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(SQLExpression.rowValue([-alias[Column("a")]])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([-alias[Column("a")]])!.column(db, for: alias, acceptsBijection: true), "a")
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression, 2.sqlExpression])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression, 2.sqlExpression])!.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")], 2.sqlExpression])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")], 2.sqlExpression])!.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression, alias[Column("a")]])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([1.sqlExpression, alias[Column("a")]])!.column(db, for: alias, acceptsBijection: true), nil)
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")], alias[Column("a")]])!.column(db, for: alias, acceptsBijection: false), nil)
            try XCTAssertEqual(SQLExpression.rowValue([alias[Column("a")], alias[Column("a")]])!.column(db, for: alias, acceptsBijection: true), nil)
        }
    }
    
    func testIdentifyingColumns() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            try XCTAssertEqual(Column("a").sqlExpression.identifyingColums(db, for: alias), [])
            
            // DatabaseValue
            try XCTAssertEqual("foo".sqlExpression.identifyingColums(db, for: alias), [])
            
            // SQLExpressionAssociativeBinary
            try XCTAssertEqual((alias[Column("a")] == 1 || alias[Column("b")] == 2).identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[Column("a")] == 1 && alias[Column("b")] == 2).identifyingColums(db, for: alias), ["a", "b"])
            try XCTAssertEqual((alias[Column("a")] == 1 && TableAlias()[Column("b")] == 2).identifyingColums(db, for: alias), ["a"])
            
            // SQLExpressionBetween
            try XCTAssertEqual((1...3).contains(alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionBinary
            try XCTAssertEqual((alias[Column("a")] - 1).identifyingColums(db, for: alias), [])
            
            // SQLExpressionCollate
            try XCTAssertEqual((alias[Column("a")] == 1).collating(.binary).identifyingColums(db, for: alias), ["a"])
            
            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionCount
            try XCTAssertEqual(count(alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionCountDistinct
            try XCTAssertEqual(count(distinct: alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionEqual
            try XCTAssertEqual((alias[Column("a")] == nil).identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((alias[Column("a")] == 1).identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((1 == alias[Column("a")]).identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual((-alias[Column("a")] == 1).identifyingColums(db, for: alias), ["a"])
            try XCTAssertEqual(((alias[Column("a")] * 2) == 1).identifyingColums(db, for: alias), [])
            try XCTAssertEqual(((alias[Column("a")] + 2) == 1).identifyingColums(db, for: alias), [])
            try XCTAssertEqual(((alias[Column("a")] - 2) == 1).identifyingColums(db, for: alias), [])
            try XCTAssertEqual((alias[SQLExpression.fastPrimaryKey] == 1).identifyingColums(db, for: alias), ["id"])
            try XCTAssertEqual((alias[Column("a")] == alias[Column("b")]).identifyingColums(db, for: alias), [])
            try XCTAssertEqual((TableAlias()[Column("a")] == nil).identifyingColums(db, for: alias), [])
            try XCTAssertEqual((TableAlias()[Column("a")] == 1).identifyingColums(db, for: alias), [])
            try XCTAssertEqual((SQLExpression.rowValue([alias[SQLExpression.fastPrimaryKey]])! == 1).identifyingColums(db, for: alias), ["id"])
            
            // SQLExpressionFastPrimaryKey
            try XCTAssertEqual(SQLExpression.fastPrimaryKey.identifyingColums(db, for: alias), [])
            
            // SQLExpressionFunction
            try XCTAssertEqual(length(alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpression.isEmpty
            try XCTAssertEqual(SQLExpression.isEmpty(alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionLiteral
            // SQLExpressionNot
            try XCTAssertEqual((!alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLExpressionQualifiedFastPrimaryKey
            try XCTAssertEqual(alias[SQLExpression.fastPrimaryKey].identifyingColums(db, for: alias), [])
            
            // SQLExpression.tableMatch
            // SQLExpressionUnary
            try XCTAssertEqual((-alias[Column("a")]).identifyingColums(db, for: alias), [])
            
            // SQLQualifiedColumn
            try XCTAssertEqual(alias[Column("a")].identifyingColums(db, for: alias), [])
            
            // SQLExpression.rowValue
            try XCTAssertEqual(SQLExpression.rowValue([alias[SQLExpression.fastPrimaryKey]])!.identifyingColums(db, for: alias), [])
            try XCTAssertEqual(SQLExpression.rowValue([alias[SQLExpression.fastPrimaryKey] == 1])!.identifyingColums(db, for: alias), ["id"])
        }
    }
    
    func testIdentifyingRowIDs() throws {
        try makeDatabaseQueue().write { db in
            try db.create(table: "t") { $0.autoIncrementedPrimaryKey("id") }
            let alias = TableAlias(tableName: "t")
            
            // Column
            // DatabaseValue
            // SQLExpressionAssociativeBinary
            try XCTAssertEqual((alias[Column("id")] == 1 || alias[Column("id")] == 3).identifyingRowIDs(db, for: alias), [1, 3])
            try XCTAssertEqual((alias[Column("id")] == 1 && alias[Column("id")] == 3).identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual((alias[Column("id")] == 1 && alias[Column("id")] == 1).identifyingRowIDs(db, for: alias), [1])
            
            // SQLExpressionBetween
            try XCTAssertEqual((0...Int.max).contains(TableAlias()[Column("id")]).identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionBinary
            // SQLExpressionCollate
            // SQLExpressionContains
            try XCTAssertEqual([1, 2, 3].contains(TableAlias()[Column("id")]).identifyingRowIDs(db, for: alias), nil)
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("id")]).identifyingRowIDs(db, for: alias), [1, 2, 3])
            try XCTAssertEqual([].contains(alias[Column("id")]).identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual([1, 2, 3].contains(alias[Column("id")] + 1).identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionCount
            // SQLExpressionCountDistinct
            // SQLExpressionEqual
            try XCTAssertEqual((TableAlias()[Column("id")] == 1).identifyingRowIDs(db, for: alias), nil)
            try XCTAssertEqual((alias[Column("id")] == 1).identifyingRowIDs(db, for: alias), [1])
            try XCTAssertEqual((alias[Column("id")] == nil).identifyingRowIDs(db, for: alias), [])
            try XCTAssertEqual(((alias[Column("id")] + 1) == 2).identifyingRowIDs(db, for: alias), nil)
            
            // SQLExpressionFastPrimaryKey
            // SQLExpressionFunction
            // SQLExpression.isEmpty
            // SQLExpressionLiteral
            // SQLExpressionNot
            // SQLExpressionQualifiedFastPrimaryKey
            // SQLExpression.tableMatch
            // SQLExpressionUnary
            // SQLQualifiedColumn
            // SQLExpression.rowValue
        }
    }

    func testIsConstantInRequest() {
        // Column
        XCTAssertFalse(Column("a").sqlExpression.isConstantInRequest)
        
        // DatabaseValue
        XCTAssertTrue(1.sqlExpression.isConstantInRequest)
        
        // SQLExpressionAssociativeBinary
        XCTAssertTrue([].joined(operator: .multiply).isConstantInRequest)
        XCTAssertTrue([1.databaseValue].joined(operator: .multiply).isConstantInRequest)
        XCTAssertFalse([Column("a")].joined(operator: .multiply).isConstantInRequest)
        XCTAssertTrue([1.databaseValue, 2.databaseValue].joined(operator: .multiply).isConstantInRequest)
        XCTAssertFalse([Column("a"), 2.databaseValue].joined(operator: .multiply).isConstantInRequest)
        XCTAssertFalse([1.databaseValue, Column("a")].joined(operator: .multiply).isConstantInRequest)
        
        // SQLExpressionBetween
        XCTAssertTrue((1...3).contains(1.databaseValue).isConstantInRequest)
        XCTAssertFalse((1...3).contains(Column("a")).isConstantInRequest)
        
        // SQLExpressionBinary
        XCTAssertTrue((1.databaseValue - 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((Column("a") - 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((1.databaseValue - Column("a")).isConstantInRequest)
        
        // CAST
        XCTAssertTrue(cast(1.databaseValue, as: .real).isConstantInRequest)
        XCTAssertFalse(cast(Column("a"), as: .real).isConstantInRequest)

        // SQLExpressionCollate
        XCTAssertTrue("foo".databaseValue.collating(.binary).isConstantInRequest)
        XCTAssertFalse(Column("a").collating(.binary).isConstantInRequest)
        
        // SQLExpressionContains
        XCTAssertFalse([1, 2, 3].contains(Column("a")).isConstantInRequest)
        
        // SQLExpressionCount
        XCTAssertFalse(count(Column("a")).isConstantInRequest)
        
        // SQLExpressionCountDistinct
        XCTAssertFalse(count(distinct: Column("a")).isConstantInRequest)
        
        // SQLExpressionEqual
        XCTAssertTrue((1.databaseValue == 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((Column("a") == 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((1.databaseValue == Column("a")).isConstantInRequest)
        
        // SQLExpressionFastPrimaryKey
        XCTAssertFalse(SQLExpression.fastPrimaryKey.isConstantInRequest)
        
        // SQLExpressionFunction
        XCTAssertTrue(length("foo".databaseValue).isConstantInRequest)
        XCTAssertFalse(length(Column("a")).isConstantInRequest)
        
        // SQLExpression.isEmpty
        XCTAssertTrue(SQLExpression.isEmpty("foo".sqlExpression).isConstantInRequest)
        XCTAssertFalse(SQLExpression.isEmpty(Column("a").sqlExpression).isConstantInRequest)

        // SQLExpressionLiteral
        XCTAssertFalse(SQL("1").sqlExpression.isConstantInRequest)
        
        // SQLExpressionNot
        XCTAssertTrue((!(true.databaseValue)).isConstantInRequest)
        XCTAssertFalse((!Column("a")).isConstantInRequest)
        
        // SQLExpressionQualifiedFastPrimaryKey
        XCTAssertFalse(SQLExpression.fastPrimaryKey.qualified(with: TableAlias()).isConstantInRequest)
        
        // SQLExpression.tableMatch
        XCTAssertFalse(SQLExpression.tableMatch(TableAlias(), "foo".sqlExpression).isConstantInRequest)
        
        // SQLExpressionUnary
        XCTAssertTrue((-(1.databaseValue)).isConstantInRequest)
        XCTAssertFalse((-Column("a")).isConstantInRequest)
        
        // SQLQualifiedColumn
        XCTAssertFalse(Column("a").sqlExpression.qualified(with: TableAlias()).isConstantInRequest)
        
        // SQLExpression.rowValue
        XCTAssertTrue(SQLExpression.rowValue([1.sqlExpression])!.isConstantInRequest)
        XCTAssertFalse(SQLExpression.rowValue([Column("a").sqlExpression])!.isConstantInRequest)
        XCTAssertTrue(SQLExpression.rowValue([1.sqlExpression, 2.sqlExpression])!.isConstantInRequest)
        XCTAssertFalse(SQLExpression.rowValue([Column("a").sqlExpression, 2.sqlExpression])!.isConstantInRequest)
        XCTAssertFalse(SQLExpression.rowValue([1.sqlExpression, Column("a").sqlExpression])!.isConstantInRequest)
    }
}
