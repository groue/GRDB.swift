/// The BelongsTo association sets up a one-to-one connection from a record
/// type to another record type, such as each instance of the declaring record
/// "belongs to" an instance of the other record.
///
/// For example, if your application includes authors and books, and each book
/// is assigned its author, you'd declare the association this way:
///
///     struct Author: TableRecord { ... }
///     struct Book: TableRecord {
///         static let author = belongsTo(Author.self)
///         ...
///     }
///
/// A BelongsTo associations should be supported by an SQLite foreign key.
///
/// Foreign keys are the recommended way to declare relationships between
/// database tables because not only will SQLite guarantee the integrity of your
/// data, but GRDB will be able to use those foreign keys to automatically
/// configure your association.
///
/// You define the foreign key when you create database tables. For example:
///
///     try db.create(table: "author") { t in
///         t.autoIncrementedPrimaryKey("id")             // (1)
///         t.column("name", .text)
///     }
///     try db.create(table: "book") { t in
///         t.autoIncrementedPrimaryKey("id")
///         t.column("authorId", .integer)                // (2)
///             .notNull()                                // (3)
///             .indexed()                                // (4)
///             .references("author", onDelete: .cascade) // (5)
///         t.column("title", .text)
///     }
///
/// 1. The author table has a primary key.
/// 2. The book.authorId column is used to link a book to the author it
///    belongs to.
/// 3. Make the book.authorId column not null if you want SQLite to guarantee
///    that all books have an author.
/// 4. Create an index on the book.authorId column in order to ease the
///    selection of an author's books.
/// 5. Create a foreign key from book.authorId column to authors.id, so that
///    SQLite guarantees that no book refers to a missing author. The
///    `onDelete: .cascade` option has SQLite automatically delete all of an
///    author's books when that author is deleted.
///    See https://sqlite.org/foreignkeys.html#fk_actions for more information.
///
/// The example above uses auto-incremented primary keys. But generally
/// speaking, all primary keys are supported.
///
/// If the database schema does not define foreign keys between tables, you can
/// still use BelongsTo associations. But your help is needed to define the
/// missing foreign key:
///
///     struct Book: FetchableRecord, TableRecord {
///         static let author = belongsTo(Author.self, using: ForeignKey(...))
///     }
///
/// See ForeignKey for more information.
public struct BelongsToAssociation<Origin: TableRecord, Destination: TableRecord>: AssociationToOne {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var sqlAssociation: SQLAssociation
    
    /// :nodoc:
    public init(sqlAssociation: SQLAssociation) {
        self.sqlAssociation = sqlAssociation
    }
    
    init(
        key: String?,
        using foreignKey: ForeignKey?)
    {
        let foreignKeyRequest = SQLForeignKeyRequest(
            originTable: Origin.databaseTableName,
            destinationTable: Destination.databaseTableName,
            foreignKey: foreignKey)
        
        let condition = SQLAssociationCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: true)
        
        let associationKey: SQLAssociationKey
        if let key = key {
            associationKey = .fixedSingular(key)
        } else {
            associationKey = .inflected(Destination.databaseTableName)
        }
        
        sqlAssociation = SQLAssociation(
            key: associationKey,
            condition: condition,
            relation: Destination.all().relation,
            cardinality: .toOne)
    }
}
