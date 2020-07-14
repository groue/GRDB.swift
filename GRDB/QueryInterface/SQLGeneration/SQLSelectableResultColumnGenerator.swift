extension SQLSelectable {
    /// Returns the SQL that feeds the selection of a `SELECT` statement.
    ///
    /// For example:
    ///
    ///     1
    ///     name
    ///     COUNT(*)
    ///     (score + bonus) AS total
    ///
    /// See https://sqlite.org/syntax/result-column.html
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func resultColumnSQL(_ context: SQLGenerationContext) throws -> String {
        var generator = SQLSelectableResultColumnGenerator(context: context)
        try _accept(&generator)
        return generator.resultSQL
    }
}

private struct SQLSelectableResultColumnGenerator: _SQLSelectableVisitor {
    let context: SQLGenerationContext
    var resultSQL = ""
    
    // MARK: - _SQLSelectableVisitor
    
    mutating func visit(_ selectable: AllColumns) throws {
        resultSQL = "*"
    }
    
    mutating func visit(_ selectable: _SQLAliasedExpression) throws {
        try selectable.expression._accept(&self)
        resultSQL += " AS " + selectable.name.quotedDatabaseIdentifier
    }
    
    mutating func visit(_ selectable: _SQLQualifiedAllColumns) throws {
        if let qualifier = context.qualifier(for: selectable.alias) {
            resultSQL = qualifier.quotedDatabaseIdentifier + "."
        }
        resultSQL += "*"
    }
    
    mutating func visit(_ selectable: _SQLSelectionLiteral) throws {
        resultSQL = try selectable.sqlLiteral.sql(context)
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
