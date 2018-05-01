// MARK: - SQLSelectable

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
///
/// :nodoc:
public protocol SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func resultColumnSQL(_ context: inout SQLGenerationContext) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func countedSQL(_ context: inout SQLGenerationContext) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func count(distinct: Bool) -> SQLCount?
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func columnCount(_ db: Database) throws -> Int
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable
}

// MARK: - SQLSelectionLiteral

struct SQLSelectionLiteral : SQLSelectable {
    let sql: String
    let arguments: StatementArguments?
    
    init(_ sql: String, arguments: StatementArguments? = nil) {
        self.sql = sql
        self.arguments = arguments
    }
    
    func resultColumnSQL(_ context: inout SQLGenerationContext) -> String {
        if let arguments = arguments {
            if context.appendArguments(arguments) == false {
                // GRDB limitation: we don't know how to look for `?` in sql and
                // replace them with with literals.
                fatalError("Not implemented")
            }
        }
        return sql
    }
    
    func countedSQL(_ context: inout SQLGenerationContext) -> String {
        fatalError("Selection literals can't be counted. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func count(distinct: Bool) -> SQLCount? {
        fatalError("Selection literals can't be counted. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func columnCount(_ db: Database) throws -> Int {
        fatalError("Selection literals don't known how many columns they contain. To resolve this error, select one or several SQLExpressionLiteral instead.")
    }
    
    func qualifiedSelectable(with alias: TableAlias) -> SQLSelectable {
        return self
    }
}

// MARK: - Counting

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// :nodoc:
public enum SQLCount {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Represents COUNT(*)
    case all
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    ///
    /// Represents COUNT(DISTINCT expression)
    case distinct(SQLExpression)
}
