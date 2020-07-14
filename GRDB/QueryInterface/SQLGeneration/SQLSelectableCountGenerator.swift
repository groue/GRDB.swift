extension SQLSelectable {
    /// Returns the SQL that feeds the argument of the `COUNT` function.
    ///
    /// For example:
    ///
    ///     COUNT(*)
    ///     COUNT(id)
    ///           ^---- countedSQL
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func countedSQL(_ context: SQLGenerationContext) throws -> String {
        var generator = SQLSelectableCountGenerator(context: context)
        try _accept(&generator)
        return generator.resultSQL
    }
}

private struct SQLSelectableCountGenerator: _SQLSelectableVisitor {
    let context: SQLGenerationContext
    var resultSQL = ""
    
    // MARK: - _SQLSelectableVisitor
    
    mutating func visit(_ selectable: AllColumns) throws {
        resultSQL = "*"
    }
    
    mutating func visit(_ selectable: _SQLAliasedExpression) throws {
        try selectable.expression._accept(&self)
    }
    
    mutating func visit(_ selectable: _SQLQualifiedAllColumns) throws {
        if context.qualifier(for: selectable.alias) != nil {
            // SELECT COUNT(t.*) is invalid SQL
            fatalError("Not implemented, or invalid query")
        }
        resultSQL = "*"
    }
    
    mutating func visit(_ selectable: _SQLSelectionLiteral) throws {
        fatalError("""
            Selection literals can't be counted. \
            To resolve this error, select one or several literal expressions instead. \
            See SQLLiteral.sqlExpression.
            """)
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
