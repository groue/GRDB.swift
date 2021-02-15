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
public protocol ColumnExpression: SQLSpecificExpressible {
    /// The unqualified name of a database column.
    ///
    /// "score" is a valid unqualified name. "player.score" is not.
    var name: String { get }
}

extension ColumnExpression {
    public var sqlExpression: SQLExpression {
        .column(name)
    }
}

/// A column in a database table.
///
/// When you need to introduce your own column type, don't wrap a Column.
/// Instead, adopt the ColumnExpression protocol.
///
/// See https://github.com/groue/GRDB.swift#the-query-interface
public struct Column: ColumnExpression, Equatable {
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

/// Support for column enums:
///
///     struct Player {
///         enum Columns: String, ColumnExpression {
///             case id, name, score
///         }
///     }
extension ColumnExpression where Self: RawRepresentable, Self.RawValue == String {
    public var name: String { rawValue }
}
