/// Adopt the ColumnExpression protocol in order to define a custom column type.
///
/// You can, for example, define a String-based column enum:
///
///     enum Columns: String, ColumnExpression {
///         case id, name, score
///     }
///     let nameColumn = Columns.name
///     let arthur = try Player.filter(nameColumn == "Arthur").fetchOne(db)
///
/// You can also define a genuine column type:
///
///     struct MyColumn: ColumnExpression {
///         var name: String
///         var sqlType: String
///     }
///     let nameColumn = MyColumn(name: "name", sqlType: "VARCHAR")
///     let arthur = try Player.filter(nameColumn == "Arthur").fetchOne(db)
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
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
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func resolvedExpression(inContext context: [SQLTableQualifier: PersistenceContainer]) -> SQLExpression {
        return self
    }
}

/// A column in a database table.
///
/// When you need to introduce your own column type, don't wrap a Column.
/// Instead, adopt the ColumnExpression protocol.
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
        if let qualifierName = qualifier.qualifiedName {
            return qualifierName.quotedDatabaseIdentifier + "." + name.quotedDatabaseIdentifier
        }
        return name.quotedDatabaseIdentifier
    }
    
    func qualifiedExpression(with qualifier: SQLTableQualifier) -> SQLExpression {
        // Never requalify
        return self
    }
    
    func resolvedExpression(inContext context: [SQLTableQualifier: PersistenceContainer]) -> SQLExpression {
        guard
            let container = context[qualifier],
            let value = container.value(forCaseInsensitiveColumn: name) else
        {
            return self
        }
        return value
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
