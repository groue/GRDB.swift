// MARK: - SQLStar

struct SQLStar : SQLSelectable {
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    func count(distinct: Bool) -> SQLCount? {
        // SELECT DISTINCT * FROM tableName ...
        guard !distinct else {
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return .star
    }
}


// MARK: - SQLAliasedExpression

struct SQLAliasedExpression : SQLSelectable {
    let expression: SQLExpression
    let alias: String
    
    init(_ expression: SQLExpression, alias: String) {
        self.expression = expression
        self.alias = alias
    }
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.resultColumnSQL(&arguments) + " AS " + alias.quotedDatabaseIdentifier
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return expression.countedSQL(&arguments)
    }
    
    func count(distinct: Bool) -> SQLCount? {
        return expression.count(distinct: distinct)
    }
}
