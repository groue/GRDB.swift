extension SQLExpression {
    /// Returns an SQL string that represents the expression.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    /// - parameter wrappedInParenthesis: If true, the returned SQL should be
    ///   wrapped inside parenthesis.
    func expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        var generator = SQLExpressionGenerator(context: context, wrappedInParenthesis: wrappedInParenthesis)
        try _accept(&generator)
        return generator.resultSQL
    }
}

private struct SQLExpressionGenerator: _SQLExpressionVisitor {
    let context: SQLGenerationContext
    let wrappedInParenthesis: Bool
    var resultSQL = ""
    
    mutating func visit(_ dbValue: DatabaseValue) throws {
        if dbValue.isNull {
            // fast path for NULL
            resultSQL = "NULL"
        } else if context.append(arguments: [dbValue]) {
            // Use statement arguments
            resultSQL = "?"
        } else {
            // Quoting needed: just use SQLite, which knows better.
            resultSQL = try String.fetchOne(context.db, sql: "SELECT QUOTE(?)", arguments: [dbValue])!
        }
    }
    
    mutating func visit<Column>(_ column: Column) throws where Column: ColumnExpression {
        resultSQL = column.name.quotedDatabaseIdentifier
    }
    
    mutating func visit(_ column: _SQLQualifiedColumn) throws {
        if let qualifier = context.qualifier(for: column.alias) {
            resultSQL = qualifier.quotedDatabaseIdentifier + "."
        }
        resultSQL += column.name.quotedDatabaseIdentifier
    }
    
    mutating func visit(_ expr: _SQLExpressionBetween) throws {
        resultSQL = try """
            \(expr.expression.expressionSQL(context, wrappedInParenthesis: true)) \
            \(expr.isNegated ? "NOT BETWEEN" : "BETWEEN") \
            \(expr.lowerBound.expressionSQL(context, wrappedInParenthesis: true)) \
            AND \
            \(expr.upperBound.expressionSQL(context, wrappedInParenthesis: true))
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionBinary) throws {
        resultSQL = try """
            \(expr.lhs.expressionSQL(context, wrappedInParenthesis: true)) \
            \(expr.op.sql) \
            \(expr.rhs.expressionSQL(context, wrappedInParenthesis: true))
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionAssociativeBinary) throws {
        let expressionSQLs = try expr.expressions.map {
            try $0.expressionSQL(context, wrappedInParenthesis: true)
        }
        let joiner = " \(expr.op.sql) "
        resultSQL = expressionSQLs.joined(separator: joiner)
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCollate) throws {
        resultSQL = try """
            \(expr.expression.expressionSQL(context, wrappedInParenthesis: false)) \
            COLLATE \
            \(expr.collationName.rawValue)
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionContains) throws {
        resultSQL = try """
            \(expr.expression.expressionSQL(context, wrappedInParenthesis: true)) \
            \(expr.isNegated ? "NOT IN" : "IN") \
            (\(expr.collection.collectionSQL(context)))
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionCount) throws {
        resultSQL = try "COUNT(" + expr.counted.countedSQL(context) + ")"
    }
    
    mutating func visit(_ expr: _SQLExpressionCountDistinct) throws {
        resultSQL = try "COUNT(DISTINCT " + expr.counted.expressionSQL(context, wrappedInParenthesis: false) + ")"
    }
    
    mutating func visit(_ expr: _SQLExpressionEqual) throws {
        resultSQL = try """
            \(expr.lhs.expressionSQL(context, wrappedInParenthesis: true)) \
            \(expr.op.rawValue) \
            \(expr.rhs.expressionSQL(context, wrappedInParenthesis: true))
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionFastPrimaryKey) throws {
        // Likely a GRDB bug: how comes this expression is used before it
        // has been qualified?
        fatalError("_SQLExpressionFastPrimaryKey is not qualified.")
    }
    
    mutating func visit(_ expr: _SQLExpressionFunction) throws {
        resultSQL = expr.function
        resultSQL += "("
        resultSQL += try expr.arguments
            .map { try $0.expressionSQL(context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
        resultSQL += ")"
    }
    
    mutating func visit(_ expr: _SQLExpressionIsEmpty) throws {
        resultSQL = try """
            \(expr.countExpression.expressionSQL(context, wrappedInParenthesis: true)) \
            \(expr.isEmpty ? "= 0" : "> 0")
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionLiteral) throws {
        resultSQL = try expr.sqlLiteral.sql(context)
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionNot) throws {
        resultSQL = try "NOT \(expr.expression.expressionSQL(context, wrappedInParenthesis: true))"
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionQualifiedFastPrimaryKey) throws {
        let column = try expr.columnName(context.db)
        try _SQLQualifiedColumn(column, alias: expr.alias)._accept(&self)
    }
    
    mutating func visit(_ expr: _SQLExpressionTableMatch) throws {
        resultSQL = try """
            \(context.resolvedName(for: expr.alias).quotedDatabaseIdentifier) \
            MATCH \
            \(expr.pattern.expressionSQL(context, wrappedInParenthesis: true))
            """
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    mutating func visit(_ expr: _SQLExpressionUnary) throws {
        resultSQL = try expr.op.sql
            + (expr.op.needsRightSpace ? " " : "")
            + expr.expression.expressionSQL(context, wrappedInParenthesis: true)
        if wrappedInParenthesis {
            resultSQL = "(\(resultSQL))"
        }
    }
    
    // MARK: _FetchRequestVisitor
    
    mutating func visit<Base: FetchRequest>(_ request: AdaptedFetchRequest<Base>) throws {
        let sql = try request.requestSQL(context, forSingleResult: false)
        resultSQL = "(\(sql))"
    }
    
    mutating func visit<RowDecoder>(_ request: QueryInterfaceRequest<RowDecoder>) throws {
        let sql = try request.requestSQL(context, forSingleResult: false)
        resultSQL = "(\(sql))"
    }
    
    mutating func visit<RowDecoder>(_ request: SQLRequest<RowDecoder>) throws {
        let sql = try request.requestSQL(context, forSingleResult: false)
        resultSQL = "(\(sql))"
    }
}
