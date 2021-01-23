/// A **HasOneThrough** association sets up a one-to-one connection with
/// another record. This association indicates that the declaring record can be
/// matched with one instance of another record by proceeding through a third
/// record. For example, if each book belongs to a library, and each library has
/// one address, then one knows where the book should be returned to:
///
///     struct Book: TableRecord {
///         static let library = belongsTo(Library.self)
///         static let returnAddress = hasOne(Address.self, through: library, using: Library.address)
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
    public var _sqlAssociation: _SQLAssociation
    
    /// :nodoc:
    public init(sqlAssociation: _SQLAssociation) {
        self._sqlAssociation = sqlAssociation
    }
}
