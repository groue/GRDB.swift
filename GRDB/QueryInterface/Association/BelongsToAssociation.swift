public struct BelongsToAssociation<Origin, Destination>: Association {
    fileprivate let joinConditionRequest: ForeignKeyJoinConditionRequest
    
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination

    public var key: String
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>

    public func forKey(_ key: String) -> BelongsToAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try joinConditionRequest.fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> BelongsToAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

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
        
        let joinConditionRequest = ForeignKeyJoinConditionRequest(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: true)

        return BelongsToAssociation(
            joinConditionRequest: joinConditionRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(Destination.all()))
    }
}
