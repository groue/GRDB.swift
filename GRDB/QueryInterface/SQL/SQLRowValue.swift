/// A [row value](https://www.sqlite.org/rowvalue.html).
///
/// :nodoc:
struct SQLRowValue: SQLExpression {
    let expressions: [SQLExpression]
    
    /// SQLite row values were shipped in SQLite 3.15:
    /// https://www.sqlite.org/releaselog/3_15_0.html
    static let isAvailable = (sqlite3_libversion_number() >= 3015000)
    
    /// - precondition: `expressions` is not empty
    init(_ expressions: [SQLExpression]) {
        assert(!expressions.isEmpty)
        self.expressions = expressions
    }
    
    // MARK: - SQLExpression
    
    func _column(_ db: Database, for alias: TableAlias, acceptsBijection: Bool) throws -> String? {
        if let expression = expressions.first, expressions.count == 1 {
            return try expression._column(db, for: alias, acceptsBijection: acceptsBijection)
        }
        
        return nil
    }
    
    func _expressionSQL(_ context: SQLGenerationContext, wrappedInParenthesis: Bool) throws -> String {
        if let expression = expressions.first, expressions.count == 1 {
            return try expression._expressionSQL(context, wrappedInParenthesis: wrappedInParenthesis)
        }
        
        let values = try expressions.map {
            try $0._expressionSQL(context, wrappedInParenthesis: false)
        }
        
        return "("
            + values.joined(separator: ", ")
            + ")"
    }
    
    func _identifyingColums(_ db: Database, for alias: TableAlias) throws -> Set<String> {
        if let expression = expressions.first, expressions.count == 1 {
            return try expression._identifyingColums(db, for: alias)
        }
        
        return try expressions.reduce(into: []) { try $0.formUnion($1._identifyingColums(db, for: alias)) }
    }
    
    var _isConstantInRequest: Bool {
        expressions.allSatisfy(\._isConstantInRequest)
    }
    
    var _isTrue: Bool {
        if let expression = expressions.first, expressions.count == 1 {
            return expression._isTrue
        }
        
        return false
    }
    
    func _qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        SQLRowValue(expressions.map { $0._qualifiedExpression(with: alias) })
    }
    
    // MARK: - SQLSelectable
    
    var _isAggregate: Bool {
        expressions.contains(where: \._isAggregate)
    }
}
