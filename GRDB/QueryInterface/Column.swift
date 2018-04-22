/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column : SQLExpression {
    /// The hidden rowID column
    public static let rowID = Column("rowid")
    
    /// The name of the column
    public let name: String
    
    /// Creates a column given its name.
    public init(_ name: String) {
        self.name = name
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return name.quotedDatabaseIdentifier
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with qualifier: SQLTableQualifier) -> SQLExpression {
        return QualifiedColumn(name, qualifier: qualifier)
    }
}

/// A qualified column in the database, as in `SELECT t.a FROM t`
struct QualifiedColumn : SQLExpression {
    let name: String
    private var qualifier: SQLTableQualifier
    
    /// Creates a column given its name.
    init(_ name: String, qualifier: SQLTableQualifier) {
        self.name = name
        self.qualifier = qualifier
    }
    
    func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        if let qualifierName = qualifier.name {
            return qualifierName.quotedDatabaseIdentifier + "." + name.quotedDatabaseIdentifier
        }
        return name.quotedDatabaseIdentifier
    }
    
    func qualifiedExpression(with qualifier: SQLTableQualifier) -> SQLExpression {
        // Never requalify
        return self
    }
}
