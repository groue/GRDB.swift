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
public struct HasManyAssociation<Origin, Destination>: Association {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination

    public var key: String
    
    /// :nodoc:
    public let joinCondition: JoinCondition
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>
    
    public func forKey(_ key: String) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

// Allow HasManyAssociation(...).filter(key: ...)
extension HasManyAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension HasManyAssociation where Origin: TableRecord, Destination: TableRecord {
    private func makeAggregate(_ expression: SQLExpression) -> AssociationAggregate<Origin> {
        return AssociationAggregate { request in
            let tableAlias = TableAlias()
            let request = request
                .joining(optional: self.aliased(tableAlias))
                .groupByPrimaryKey()
            let expression = tableAlias[expression]
            return (request: request, expression: expression)
        }
    }
    
    /// The number of associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.count())
    public var count: AssociationAggregate<Origin> {
        return makeAggregate(SQLExpressionCountDistinct(Column.rowID)).aliased("\(key)Count")
    }
    
    /// An aggregate that is true if there exists no associated records.
    ///
    /// For example:
    ///
    ///     Team.having(Team.players.isEmpty())
    ///     Team.having(!Team.players.isEmpty())
    ///     Team.having(Team.players.isEmpty() == false)
    public var isEmpty: AssociationAggregate<Origin> {
        return makeAggregate(SQLExpressionIsEmpty(SQLExpressionCountDistinct(Column.rowID)))
    }
    
    /// The average value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.average(Column("score")))
    public func average(_ expression: SQLExpressible) -> AssociationAggregate<Origin> {
        let aggregate = makeAggregate(SQLExpressionFunction(.avg, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("average\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// The maximum value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.max(Column("score")))
    public func max(_ expression: SQLExpressible) -> AssociationAggregate<Origin> {
        let aggregate = makeAggregate(SQLExpressionFunction(.max, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("max\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }
    
    /// The minimum value of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.min(Column("score")))
    public func min(_ expression: SQLExpressible) -> AssociationAggregate<Origin> {
        let aggregate = makeAggregate(SQLExpressionFunction(.min, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("min\(key.uppercasingFirstCharacter)\(column.name.uppercasingFirstCharacter)")
        } else {
            return aggregate
        }
    }

    /// The sum of the given expression in associated records.
    ///
    /// For example:
    ///
    ///     Team.annotated(with: Team.players.min(Column("score")))
    public func sum(_ expression: SQLExpressible) -> AssociationAggregate<Origin> {
        let aggregate = makeAggregate(SQLExpressionFunction(.sum, arguments: expression))
        if let column = expression as? ColumnExpression {
            return aggregate.aliased("\(key)\(column.name.uppercasingFirstCharacter)Sum")
        } else {
            return aggregate
        }
    }
}

extension TableRecord {
    /// Creates a "Has many" association between Self and the
    /// destination type.
    ///
    ///     struct Book: TableRecord { ... }
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (author, book) pairs:
    ///     let request = Author.including(required: Author.books)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Authorship: FetchableRecord, Decodable {
    ///         var author: Author
    ///         var book: Book
    ///     }
    ///
    ///     let authorships = try dbQueue.read { db in
    ///         return try Authorship.fetchAll(db, request)
    ///     }
    ///     for authorship in authorships {
    ///         print("\(authorship.author.name) wrote \(authorship.book.title)")
    ///     }
    ///
    /// It is recommended that you define, alongside the association, a property
    /// with the same name:
    ///
    ///     struct Author: TableRecord {
    ///         static let books = hasMany(Book.self)
    ///         var books: QueryInterfaceRequest<Book> {
    ///             return request(for: Author.books)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let author: Author = ...
    ///         let books = try author.books.fetchAll(db) // [Book]
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
    public static func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasManyAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: Destination.databaseTableName,
            destinationTable: databaseTableName,
            foreignKey: foreignKey)
        
        let joinCondition = JoinCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        return HasManyAssociation(
            key: key ?? Destination.databaseTableName,
            joinCondition: joinCondition,
            request: AssociationRequest(Destination.all()))
    }
}
