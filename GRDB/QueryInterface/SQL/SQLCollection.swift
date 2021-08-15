/// The right-hand side of the `IN` or `NOT IN` SQL operators
///
/// See <https://sqlite.org/lang_expr.html#the_in_and_not_in_operators>
struct SQLCollection {
    private var impl: Impl
    
    private enum Impl {
        /// An array collection
        ///
        ///     id IN (1, 2, 3)
        ///           ~~~~~~~~~
        case array([SQLExpression])
        
        /// A subquery
        ///
        ///     score IN (SELECT ...)
        ///              ~~~~~~~~~~~~
        case subquery(SQLSubquery)
        
        /// A table
        ///
        ///     score IN table
        ///              ~~~~~
        case table(String)
    }
    
    static func array(_ expressions: [SQLExpression]) -> Self {
        self.init(impl: .array(expressions))
    }
    
    static func subquery(_ subquery: SQLSubquery) -> Self {
        self.init(impl: .subquery(subquery))
    }
    
    static func table(_ tableName: String) -> Self {
        self.init(impl: .table(tableName))
    }
}

extension SQLCollection {
    /// Returns a qualified collection.
    func qualified(with alias: TableAlias) -> SQLCollection {
        switch impl {
        case .subquery,
             .table:
            return self
            
        case let .array(expressions):
            return .array(expressions.map { $0.qualified(with: alias) })
        }
    }
    
    /// The expressions in the collection, if known.
    ///
    /// This property makes it possible to track individual rows identified by
    /// their row ids, and ignore modifications to other rows:
    ///
    ///     // Track rows 1, 2, 3 only
    ///     let request = Player.filter(keys: [1, 2, 3])
    ///     let regionObservation = DatabaseRegionObservation(tracking: request)
    ///     let valueObservation = ValueObservation.tracking(request.fetchAll)
    var collectionExpressions: [SQLExpression]? {
        switch impl {
        case .subquery,
             .table:
            return nil
            
        case let .array(expressions):
            return expressions
        }
    }
    
    /// Returns an SQL string that represents the collection.
    ///
    /// - parameter context: An SQL generation context which accepts
    ///   statement arguments.
    func sql(_ context: SQLGenerationContext) throws -> String {
        switch impl {
        case let .array(expressions):
            return try "("
                + expressions.map { try $0.sql(context) }.joined(separator: ", ")
                + ")"
            
        case let .subquery(subquery):
            return try "("
                + subquery.sql(context)
                + ")"
            
        case let .table(tableName):
            return tableName.quotedDatabaseIdentifier
        }
    }
    
    /// Returns an expression that check whether the collection contains
    /// the expression.
    func contains(_ value: SQLExpression) -> SQLExpression {
        switch impl {
        case .subquery,
             .table:
            return .in(value, self)
            
        case let .array(expressions):
            guard let expression = expressions.first else {
                return false.sqlExpression
            }
                        
            if expressions.count == 1 {
                // Output `value = expression` instead of `value IN (expression)`,
                // because it looks nicer. Force the equal `=` operator, so that
                // the result evaluates just as `value IN (expression)`, even
                // if expression is NULL.
                return .compare(.equal, value, expression)
            }
            
            return .in(value, self)
        }
    }
}
