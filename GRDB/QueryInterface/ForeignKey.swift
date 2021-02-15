/// A ForeignKey helps building associations when GRDB can't infer a foreign
/// key from the database schema.
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
/// Your help is needed. You have to instruct GRDB which foreign key to use:
///
///     struct Book: TableRecord {
///         // Define foreign keys
///         static let authorForeignKey = ForeignKey(["authorId"]))
///         static let translatorForeignKey = ForeignKey(["translatorId"]))
///
///         // Use foreign keys to define associations:
///         static let author = belongsTo(Person.self, using: authorForeignKey)
///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
///     }
///
/// Foreign keys are always defined from the table that contains the columns at
/// the origin of the foreign key. Person's symmetric HasMany associations reuse
/// Book's foreign keys:
///
///     struct Person: TableRecord {
///         static let writtenBooks = hasMany(Book.self, using: Book.authorForeignKey)
///         static let translatedBooks = hasMany(Book.self, using: Book.translatorForeignKey)
///     }
///
/// Foreign keys can also be defined from query interface columns:
///
///     struct Book: TableRecord {
///         enum Columns: String, ColumnExpression {
///             case id, title, authorId, translatorId
///         }
///
///         static let authorForeignKey = ForeignKey([Columns.authorId]))
///         static let translatorForeignKey = ForeignKey([Columns.translatorId]))
///     }
///
/// When the destination table of a foreign key does not define any primary key,
/// you need to provide the full definition of a foreign key:
///
///     struct Book: TableRecord {
///         static let authorForeignKey = ForeignKey(["authorId"], to: ["id"]))
///         static let author = belongsTo(Person.self, using: authorForeignKey)
///     }
public struct ForeignKey: Equatable {
    var originColumns: [String]
    var destinationColumns: [String]?
    
    /// Creates a ForeignKey intended to define a record association.
    ///
    ///     struct Book: TableRecord {
    ///         // Define foreign keys
    ///         static let authorForeignKey = ForeignKey(["authorId"]))
    ///         static let translatorForeignKey = ForeignKey(["translatorId"]))
    ///
    ///         // Use foreign keys to define associations:
    ///         static let author = belongsTo(Person.self, using: authorForeignKey)
    ///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
    ///     }
    ///
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. When nil (the default), GRDB automatically uses the
    /// primary key.
    public init(_ originColumns: [String], to destinationColumns: [String]? = nil) {
        self.originColumns = originColumns
        self.destinationColumns = destinationColumns
    }
    
    /// Creates a ForeignKey intended to define a record association.
    ///
    ///     struct Book: TableRecord {
    ///         // Define columns
    ///         enum Columns: String, ColumnExpression {
    ///             case id, title, authorId, translatorId
    ///         }
    ///
    ///         // Define foreign keys
    ///         static let authorForeignKey = ForeignKey([Columns.authorId]))
    ///         static let translatorForeignKey = ForeignKey([Columns.translatorId]))
    ///
    ///         // Use foreign keys to define associations:
    ///         static let author = belongsTo(Person.self, using: authorForeignKey)
    ///         static let translator = belongsTo(Person.self, using: translatorForeignKey)
    ///     }
    ///
    /// - parameter originColumns: The columns at the origin of the foreign key.
    /// - parameter destinationColumns: The columns at the destination of the
    /// foreign key. When nil (the default), GRDB automatically uses the
    /// primary key.
    public init(_ originColumns: [ColumnExpression], to destinationColumns: [ColumnExpression]? = nil) {
        self.init(originColumns.map(\.name), to: destinationColumns?.map(\.name))
    }
}
