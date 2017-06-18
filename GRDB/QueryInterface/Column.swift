/// A column in the database
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column {
    /// The hidden rowID column
    public static let rowID = Column("rowid")
    
    /// The name of the column
    public let name: String
    
    /// Creates a column given its name.
    public init(_ name: String) {
        self.name = name
    }
}

extension Column : SQLExpression {
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    public func expressionSQL(_ arguments: inout StatementArguments?) -> String {
        return name.quotedDatabaseIdentifier
    }
}
