import XCTest
@testable import GRDB

class SQLExpressionIsConstantTests: XCTestCase {
    func testIsConstant() {
        XCTAssertTrue(1.databaseValue.isConstantInRequest)
        
        XCTAssertFalse(Column("a").isConstantInRequest)
        
        XCTAssertFalse(Column("a")._qualifiedExpression(with: TableAlias()).isConstantInRequest)
        
        XCTAssertTrue(SQLDateModifier.day(1).isConstantInRequest)
        
        XCTAssertTrue((1...3).contains(1.databaseValue).isConstantInRequest)
        XCTAssertFalse((1...3).contains(Column("a")).isConstantInRequest)
        
        XCTAssertTrue("foo".databaseValue.collating(.binary).sqlExpression.isConstantInRequest)
        XCTAssertFalse(Column("a").collating(.binary).sqlExpression.isConstantInRequest)
        
        XCTAssertFalse([1, 2, 3].contains(Column("a")).isConstantInRequest)
        
        XCTAssertTrue((1.databaseValue - 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((Column("a") - 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((1.databaseValue - Column("a")).isConstantInRequest)
        
        XCTAssertTrue([1.databaseValue, 2.databaseValue].joined(operator: .multiply).isConstantInRequest)
        XCTAssertFalse([Column("a"), 2.databaseValue].joined(operator: .multiply).isConstantInRequest)
        XCTAssertFalse([1.databaseValue, Column("a")].joined(operator: .multiply).isConstantInRequest)
        
        XCTAssertTrue((1.databaseValue == 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((Column("a") == 2.databaseValue).isConstantInRequest)
        XCTAssertFalse((1.databaseValue == Column("a")).isConstantInRequest)
        
        XCTAssertFalse(_SQLExpressionFastPrimaryKey().isConstantInRequest)
        
        XCTAssertFalse(_SQLExpressionFastPrimaryKey()._qualifiedExpression(with: TableAlias()).isConstantInRequest)
        
        XCTAssertTrue(length("foo".databaseValue).isConstantInRequest)
        XCTAssertFalse(length(Column("a")).isConstantInRequest)
        
        XCTAssertTrue((!(true.databaseValue)).isConstantInRequest)
        XCTAssertFalse((!Column("a")).isConstantInRequest)
        
        XCTAssertTrue((-(1.databaseValue)).isConstantInRequest)
        XCTAssertFalse((Column("a")).isConstantInRequest)
    }
}
