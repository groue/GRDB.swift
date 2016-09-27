// MARK: - SQLSelectable

/// This protocol is an implementation detail of the query interface.
/// Do not use it directly.
///
/// See https://github.com/groue/GRDB.swift/#the-query-interface
///
/// # Low Level Query Interface
///
/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
public protocol SQLSelectable {
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String
    func countedSQL(_ arguments: inout StatementArguments?) -> String
    func countingSelectable(distinct: Bool, from tableName: String, aliased alias: String?) -> SQLSelectable?
}


// MARK: - SQLStar

struct SQLStar : SQLSelectable {
    fileprivate init() {
    }
    
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return "*"
    }
    
    public func countingSelectable(distinct: Bool, from tableName: String, aliased alias: String?) -> SQLSelectable? {
        // SELECT DISTINCT * FROM tableName ...
        guard !distinct else {
            return nil
        }
        
        // SELECT * FROM tableName ...
        // ->
        // SELECT COUNT(*) FROM tableName ...
        return SQLExpressionCount(self)
    }
}

let star = SQLStar()


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
    
    public func countingSelectable(distinct: Bool, from tableName: String, aliased alias: String?) -> SQLSelectable? {
        return expression.countingSelectable(distinct: distinct, from: tableName, aliased: alias)
    }
}


// MARK: - SQLExpressible

extension SQLExpressible where Self: SQLSelectable {
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.resultColumnSQL(_)
    public func resultColumnSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.countedSQL(_)
    public func countedSQL(_ arguments: inout StatementArguments?) -> String {
        return sqlExpression.expressionSQL(&arguments)
    }
    
    
    /// This method is an implementation detail of the query interface.
    /// Do not use it directly.
    ///
    /// See https://github.com/groue/GRDB.swift/#the-query-interface
    ///
    /// # Low Level Query Interface
    ///
    /// See SQLSelectable.countingSelectable(distinct:from:aliased:)
    public func countingSelectable(distinct: Bool, from tableName: String, aliased alias: String?) -> SQLSelectable? {
        return sqlExpression.countingSelectable(distinct: distinct, from: tableName, aliased: alias)
    }
}
