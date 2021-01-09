// MARK: - SQLCollection

/// Implementation details of `SQLCollection`.
///
/// :nodoc:
public protocol _SQLCollection {
    /// Returns a qualified collection.
    ///
    /// :nodoc:
    func _qualifiedCollection(with alias: TableAlias) -> SQLCollection
    
    /// The expressions in the collection, if known.
    ///
    /// This property makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    ///
    /// :nodoc:
    var _collectionExpressions: [SQLExpression]? { get }
    
    /// Returns an SQL string that represents the collection.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func _collectionSQL(_ context: SQLGenerationContext) throws -> String
}

/// SQLCollection is the protocol for types that can be checked for inclusion.
public protocol SQLCollection: _SQLCollection {
    /// Returns an expression that check whether the collection contains
    /// the expression.
    func contains(_ value: SQLExpressible) -> SQLExpression
}

// MARK: - SQLExpressionsArray

/// SQLExpressionsArray wraps an array of expressions
///
///     SQLExpressionsArray([1, 2, 3])
///
/// :nodoc:
struct SQLExpressionsArray: SQLCollection {
    let expressions: [SQLExpression]
    
    var _collectionExpressions: [SQLExpression]? { expressions }
    
    func _collectionSQL(_ context: SQLGenerationContext) throws -> String {
        try "("
            + expressions
            .map { try $0._expressionSQL(context, wrappedInParenthesis: false) }
            .joined(separator: ", ")
            + ")"
    }
    
    func contains(_ value: SQLExpressible) -> SQLExpression {
        guard let expression = expressions.first else {
            return false.databaseValue
        }
        
        // With SQLite, `expr IN (NULL)` never succeeds.
        //
        // We must not provide special handling of NULL, because we can not
        // guess if our `expressions` array contains a value evaluates to NULL.
        
        if expressions.count == 1 {
            // Output `expr = value` instead of `expr IN (value)`, because it
            // looks nicer. And make sure we do not produce 'expr IS NULL'.
            return SQLExpressionEqual(.equal, value.sqlExpression, expression)
        }
        
        return SQLExpressionContains(value, self)
    }
    
    func _qualifiedCollection(with alias: TableAlias) -> SQLCollection {
        SQLExpressionsArray(expressions: expressions.map { $0._qualifiedExpression(with: alias) })
    }
}

// MARK: - SQLTableCollection

/// SQLTableCollection aims at generating `value IN table` expressions.
///
/// :nodoc:
enum SQLTableCollection: SQLCollection {
    case tableName(String)
    
    var _collectionExpressions: [SQLExpression]? { nil }
    
    func _collectionSQL(_ context: SQLGenerationContext) throws -> String {
        switch self {
        case let .tableName(tableName):
            return tableName.quotedDatabaseIdentifier
        }
    }
    
    func contains(_ value: SQLExpressible) -> SQLExpression {
        return SQLExpressionContains(value, self)
    }
    
    func _qualifiedCollection(with alias: TableAlias) -> SQLCollection { self }
}
