/// The protocol for types that define database columns
public protocol ColumnExpression: SQLExpression {
    /// The unqualified name of a database column.
    ///
    /// "score" is a valid unqualified name. "player.score" is not.
    var name: String { get }
}

extension ColumnExpression {
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

/// A column in a database table
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column: ColumnExpression {
    /// The hidden rowID column
    public static let rowID = Column("rowid")
    
    /// The name of the column
    public var name: String
    
    /// Creates a column given its name.
    public init(_ name: String) {
        self.name = name
    }
}

/// A qualified column in the database, as in `SELECT t.a FROM t`
struct QualifiedColumn: ColumnExpression {
    var name: String
    private let qualifier: SQLTableQualifier
    
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

/// Support for column enums:
///
///     struct Player {
///         enum Columns: ColumnExpression {
///             case id, name, score
///         }
///     }
extension ColumnExpression where Self: RawRepresentable, Self.RawValue == String {
    public var name: String {
        return rawValue
    }
}
