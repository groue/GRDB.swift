/// A `ForeignKey` defines on which columns an association between two tables
/// is established.
///
/// You will need a `ForeignKey` when you define an ``Association`` between two
/// tables that are not unambiguously related with a single SQLite foreign key.
///
/// Sometimes the database schema does not define any foreign key between two
/// tables. And sometimes, there are several foreign keys from a table
/// to another:
///
///     | Table book   |       | Table person |
///     | ------------ |       | ------------ |
///     | id           |   +-->• id           |
///     | authorId     •---+   | name         |
///     | translatorId •---+
///     | title        |
///
/// When this happens, associations can't be automatically inferred from the
/// database schema. GRDB will complain with a fatal error such as "Ambiguous
/// foreign key from book to person", or "Could not infer foreign key from book
/// to person".
///
/// Your help is needed. You have to instruct which foreign key to use.
/// For example:
///
/// ```swift
/// struct Book: TableRecord {
///     // Define foreign keys
///     static let authorForeignKey = ForeignKey(["authorId"]))
///     static let translatorForeignKey = ForeignKey(["translatorId"]))
///
///     // Use foreign keys to define associations:
///     static let author = belongsTo(
///         Person.self,
///         key: "author",
///         using: authorForeignKey)
///     static let translator = belongsTo(
///         Person.self,
///         key: "translator",
///         using: translatorForeignKey)
/// }
/// ```
///
/// Foreign keys can also be defined from query interface columns:
///
/// ```swift
/// struct Book: TableRecord {
///     enum Columns: String, ColumnExpression {
///         case id, title, authorId, translatorId
///     }
///
///     static let authorForeignKey = ForeignKey([Columns.authorId]))
///     static let translatorForeignKey = ForeignKey([Columns.translatorId]))
/// }
/// ```
///
/// When the destination table does not define any primary key, you need to
/// provide the destination columns:
///
/// ```swift
/// struct Book: TableRecord {
///     static let authorForeignKey = ForeignKey(["authorId"], to: ["id"]))
///     static let translatorForeignKey = ForeignKey(["translatorId"], to: ["id"]))
/// }
/// ```
///
/// Foreign keys are always defined from the table that contains the columns at
/// the origin of the foreign key. `Person`'s symmetric associations reuse
/// foreign keys of `Book`:
///
/// ```swift
/// struct Person: TableRecord {
///     static let writtenBooks = hasMany(
///         Book.self,
///         key: "writtenBooks",
///         using: Book.authorForeignKey)
///     static let translatedBooks = hasMany(
///         Book.self,
///         key: "translatedBooks",
///         using: Book.translatorForeignKey)
/// }
/// ```
public struct ForeignKey: Equatable {
    var originColumns: [String]
    var destinationColumns: [String]?
    
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. Use nil for the columns of the primary key.
    public init(_ originColumns: [String], to destinationColumns: [String]? = nil) {
        self.originColumns = originColumns
        self.destinationColumns = destinationColumns
    }
    
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. Use nil for the columns of the primary key.
    public init(_ originColumns: [any ColumnExpression], to destinationColumns: [any ColumnExpression]? = nil) {
        self.init(originColumns.map(\.name), to: destinationColumns?.map(\.name))
    }
}
