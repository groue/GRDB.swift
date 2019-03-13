/// A **HasOneThrough** association sets up a one-to-one connection with
/// another record. This association indicates that the declaring record can be
/// matched with one instance of another record by proceeding through a third
/// record. For example, if each book belongs to a library, and each library has
/// one address, then one knows where the book should be returned to:
///
///     struct Book: TableRecord {
///         static let library = belongsTo(Library.self)
///         static let returnAddress = hasOne(Address.self, through: library, using: library.address)
///         ...
///     }
/// 
///     struct Library: TableRecord {
///         static let address = hasOne(Address.self)
///         ...
///     }
/// 
///     struct Address: TableRecord { ... }
///
/// As in the example above, **HasOneThrough** association is always built from
/// two other associations: the `through:` and `using:` arguments. Those
/// associations can be any other association to one (BelongsTo, HasOne,
/// HasOneThrough).
public struct HasOneThroughAssociation<Origin, Destination>: AssociationToOne {
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
}

// Allow HasOneThroughAssociation(...).filter(key: ...)
extension HasOneThroughAssociation: TableRequest where Destination: TableRecord { }

extension TableRecord {
    /// Creates a "Has One Through" association between Self and the
    /// destination type.
    ///
    ///     struct Book: TableRecord {
    ///         static let library = belongsTo(Library.self)
    ///         static let returnAddress = hasOne(Address.self, through: library, using: library.address)
    ///     }
    ///
    ///     struct Library: TableRecord {
    ///         static let address = hasOne(Address.self)
    ///     }
    ///
    ///     struct Address: TableRecord { ... }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (book, returnAddress) pairs:
    ///     let request = Book.including(required: Book.returnAddress)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Todo: FetchableRecord, Decodable {
    ///         var book: Book
    ///         var address: Address
    ///     }
    ///
    ///     let todos = try dbQueue.read { db in
    ///         return try Todo.fetchAll(db, request)
    ///     }
    ///     for todo in todos {
    ///         print("Please return \(todo.book) to \(todo.address)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Book: TableRecord, EncodableRecord {
    ///         static let library = belongsTo(Library.self)
    ///         static let returnAddress = hasOne(Address.self, through: library, using: library.address)
    ///         var returnAddress: QueryInterfaceRequest<Address> {
    ///             return request(for: Book.returnAddress)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let book: Book = ...
    ///         let address = try book.returnAddress.fetchOne(db) // Address?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - through: An association from Self to the intermediate type.
    ///     - using: An association from the intermediate type to the
    ///       destination type.
    public static func hasOne<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target)
        -> HasOneThroughAssociation<Self, Target.RowDecoder>
        where Pivot: AssociationToOne,
        Target: AssociationToOne,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        return HasOneThroughAssociation(sqlAssociation: target.sqlAssociation.appending(pivot.sqlAssociation))
    }
}
