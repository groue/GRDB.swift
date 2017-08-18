// MARK: - SQLSelectable

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
///
/// SQLSelectable is the protocol for types that can be selected, as
/// described at https://www.sqlite.org/syntax/result-column.html
public protocol SQLSelectable {
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func resultColumnSQL(_ arguments: inout StatementArguments?) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func countedSQL(_ arguments: inout StatementArguments?) -> String
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    func count(distinct: Bool) -> SQLCount?
}

// MARK: - Counting

/// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
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
