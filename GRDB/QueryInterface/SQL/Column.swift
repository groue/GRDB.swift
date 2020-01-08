/// Adopt the ColumnExpression protocol when you define a column type.
///
/// You can, for example, define a String-based column enum:
///
///     enum Columns: String, ColumnExpression {
///         case id, name, score
///     }
///     let arthur = try Player.filter(Columns.name == "Arthur").fetchOne(db)
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
    public func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        return name.quotedDatabaseIdentifier
    }
    
    /// [**Experimental**](http://github.com/groue/GRDB.swift#what-are-experimental-features)
    /// :nodoc:
    public func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        return QualifiedColumn(name, alias: alias)
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
    
    /// Creates a column given a CodingKey.
    public init(_ codingKey: CodingKey) {
        self.name = codingKey.stringValue
    }
}

/// A qualified column in the database, as in `SELECT t.a FROM t`
struct QualifiedColumn: ColumnExpression {
    var name: String
    let alias: TableAlias
    
    /// Creates a column given its name.
    init(_ name: String, alias: TableAlias) {
        self.name = name
        self.alias = alias
    }
    
    func expressionSQL(_ context: inout SQLGenerationContext, wrappedInParenthesis: Bool) -> String {
        if let qualifier = context.qualifier(for: alias) {
            return qualifier.quotedDatabaseIdentifier + "." + name.quotedDatabaseIdentifier
        }
        return name.quotedDatabaseIdentifier
    }
    
    func qualifiedExpression(with alias: TableAlias) -> SQLExpression {
        // Never requalify
        return self
    }
}

/// Support for column enums:
///
///     struct Player {
///         enum Columns: String, ColumnExpression {
///             case id, name, score
///         }
///     }
extension ColumnExpression where Self: RawRepresentable, Self.RawValue == String {
    public var name: String {
        return rawValue
    }
}
