public struct HasManyAssociation<Origin, Destination>: Association {
    fileprivate let joinConditionRequest: ForeignKeyJoinConditionRequest

    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination

    public var key: String
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>
    
    public func forKey(_ key: String) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try joinConditionRequest.fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

extension HasManyAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
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
        
        let joinConditionRequest = ForeignKeyJoinConditionRequest(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        return HasManyAssociation(
            joinConditionRequest: joinConditionRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(Destination.all()))
    }
}
