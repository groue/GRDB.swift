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
public struct BelongsToAssociation<Origin, Destination>: Association {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _impl: JoinAssociationImpl
    
    /// :nodoc:
    public init(_impl: JoinAssociationImpl) {
        self._impl = _impl
    }
}

// Allow BelongsToAssociation(...).filter(key: ...)
extension BelongsToAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension TableRecord {
    /// Creates a "Belongs To" association between Self and the
    /// destination type.
    ///
    ///     struct Author: TableRecord { ... }
    ///     struct Book: TableRecord {
    ///         static let author = belongsTo(Author.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all books with their authors:
    ///     let request = Book.including(optional: Book.author)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct BookInfo: FetchableRecord, Decodable {
    ///         var book: Book
    ///         var author: Author?
    ///     }
    ///
    ///     let bookInfos = try dbQueue.read { db in
    ///         return try BookInfo.fetchAll(db, request)
    ///     }
    ///     for bookInfo in bookInfos {
    ///         print("\(bookInfo.book.title) by \(bookInfo.author.name)")
    ///     }
    ///
    /// It is recommended that you define, alongside the association, a property
    /// with the same name:
    ///
    ///     struct Book: TableRecord {
    ///         static let author = belongsTo(Author.self)
    ///         var author: QueryInterfaceRequest<Author> {
    ///             return request(for: Book.author)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let book: Book = ...
    ///         let author = try book.author.fetchOne(db) // Author?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key to the destination table, or when the schema defines several
    ///       foreign keys to the destination table.
    public static func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: databaseTableName,
            destinationTable: Destination.databaseTableName,
            foreignKey: foreignKey)
        
        let joinCondition = JoinCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: true)
        
        return BelongsToAssociation(_impl: JoinAssociationImpl(
            key: key ?? Destination.databaseTableName,
            joinCondition: joinCondition,
            relation: Destination.all().relation))
    }
}
