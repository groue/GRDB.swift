extension SQLOrderingTerm {
    /// Returns the SQL that feeds the `ORDER BY` clause.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func orderingTermSQL(_ context: SQLGenerationContext) throws -> String {
        var generator = SQLOrderingGenerator(context: context)
        try _accept(&generator)
        return generator.resultSQL
    }
}

private struct SQLOrderingGenerator: _SQLOrderingTermVisitor {
    let context: SQLGenerationContext
    var resultSQL = ""
    
    // MARK: - _SQLOrderingTermVisitor
    
    mutating func visit(_ ordering: SQLCollatedExpression) throws {
        resultSQL = try ordering.sqlExpression.orderingTermSQL(context)
    }
    
    mutating func visit(_ ordering: _SQLOrdering) throws {
        switch ordering {
        case .asc(let expression):
            resultSQL = try expression.expressionSQL(context, wrappedInParenthesis: false) + " ASC"
        case .desc(let expression):
            resultSQL = try expression.expressionSQL(context, wrappedInParenthesis: false) + " DESC"
        case .ascNullsLast(let expression):
            resultSQL = try expression.expressionSQL(context, wrappedInParenthesis: false) + " ASC NULLS LAST"
        case .descNullsFirst(let expression):
            resultSQL = try expression.expressionSQL(context, wrappedInParenthesis: false) + " DESC NULLS FIRST"
        }
    }
    
    mutating func visit(_ ordering: _SQLOrderingLiteral) throws {
        resultSQL = try ordering.sqlLiteral.sql(context)
    }

    // MARK: - _SQLExpressionVisitor
    
    mutating func visit(_ expr: DatabaseValue) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit<Column: ColumnExpression>(_ expr: Column) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLQualifiedColumn) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws {
        resultSQL = try expr.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    // MARK: - _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        resultSQL = try request.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        resultSQL = try request.expressionSQL(context, wrappedInParenthesis: false)
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        resultSQL = try request.expressionSQL(context, wrappedInParenthesis: false)
    }
}
