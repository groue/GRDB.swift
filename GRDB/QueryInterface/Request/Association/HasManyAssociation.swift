/// The HasMany association indicates a one-to-many connection between two
/// record types, such as each instance of the declaring record "has many"
/// instances of the other record.
///
/// For example, if your application includes authors and books, and each author
/// is assigned zero or more books, you'd declare the association this way:
///
///     struct Book: TableRecord { ... }
///     struct Author: TableRecord {
///         static let books = hasMany(Book.self)
///         ...
///     }
///
/// HasMany associations should be supported by an SQLite foreign key.
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
/// still use HasMany associations. But your help is needed to define the
/// missing foreign key:
///
///     struct Author: TableRecord {
///         static let books = hasMany(Book.self, using: ForeignKey(...))
///     }
///
/// See ForeignKey for more information.
public struct HasManyAssociation<Origin: TableRecord, Destination: TableRecord>: AssociationToMany {
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
            originTable: Destination.databaseTableName,
            destinationTable: Origin.databaseTableName,
            foreignKey: foreignKey)
        
        let condition = SQLAssociationCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        let associationKey: SQLAssociationKey
        if let key = key {
            associationKey = .fixedPlural(key)
        } else {
            associationKey = .inflected(Destination.databaseTableName)
        }
        
        sqlAssociation = SQLAssociation(
            key: associationKey,
            condition: condition,
            relation: Destination.all().relation,
            cardinality: .toMany)
    }
    
    /// Creates a "Has one" association between the source and
    /// destination types.
    ///
    ///     struct Book: TableRecord { ... }
    ///     struct Author: TableRecord {
    ///         static let firstBook = hasMany(Book.self).order(Column("year")).first
    ///     }
    ///
    /// The association lets you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (author, firstBook) pairs:
    ///     let request = Author.including(required: Author.firstBook)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Authorship: FetchableRecord, Decodable {
    ///         var author: Author
    ///         var firstBook: Book
    ///     }
    ///
    ///     let authorships = try dbQueue.read { db in
    ///         return try Authorship.fetchAll(db, request)
    ///     }
    ///     for authorship in authorships {
    ///         print("\(authorship.author.name) wrote \(authorship.firstBook.title) first")
    ///     }
    public var first: HasOneAssociation<Origin, Destination> {
        HasOneAssociation(sqlAssociation: sqlAssociation.associationForFirst())
            .forKey("first\(key.singularizedName.uppercasingFirstCharacter)")
    }
    
    /// Creates a "Has one" association between the source and
    /// destination types.
    ///
    ///     struct Book: TableRecord { ... }
    ///     struct Author: TableRecord {
    ///         static let lastBook = hasMany(Book.self).order(Column("year")).last
    ///     }
    ///
    /// The association lets you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (author, firstBook) pairs:
    ///     let request = Author.including(required: Author.firstBook)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Authorship: FetchableRecord, Decodable {
    ///         var author: Author
    ///         var lastBook: Book
    ///     }
    ///
    ///     let authorships = try dbQueue.read { db in
    ///         return try Authorship.fetchAll(db, request)
    ///     }
    ///     for authorship in authorships {
    ///         print("\(authorship.author.name) wrote \(authorship.lastBook.title) last")
    ///     }
    public var last: HasOneAssociation<Origin, Destination> {
        reversed().first.forKey("last\(key.singularizedName.uppercasingFirstCharacter)")
    }
}
