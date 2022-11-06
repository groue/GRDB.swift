/// The `HasOneThroughAssociation` sets up a one-to-one connection with
/// another record. This association indicates that the declaring record can be
/// matched with one instance of another record by proceeding through a third
/// record.
///
/// For example, if each book belongs to a library, and each library has
/// one address, then one knows where the book should be returned to:
///
/// ```swift
/// struct Address: TableRecord { }
///
/// struct Library: TableRecord {
///     static let address = hasOne(Address.self)
/// }
///
/// struct Book: TableRecord {
///     static let library = belongsTo(Library.self)
///     static let returnAddress = hasOne(Address.self,
///                                       through: library,
///                                       using: Library.address,
///                                       key: "returnAddress")
/// }
/// ```
///
/// As in the example above, `HasOneThroughAssociation` is always built from
/// two other associations. Those associations can be any association that
/// declares a to-one connection (``AssociationToOne``).
public struct HasOneThroughAssociation<Origin, Destination> {
    public var _sqlAssociation: _SQLAssociation
    
    init<Pivot, Target>(
        through pivot: Pivot,
        using target: Target)
    where Pivot: AssociationToOne,
          Target: AssociationToOne,
          Pivot.OriginRowDecoder == Origin,
          Pivot.RowDecoder == Target.OriginRowDecoder,
          Target.RowDecoder == Destination
    {
        _sqlAssociation = target._sqlAssociation.through(pivot._sqlAssociation)
    }
}

extension HasOneThroughAssociation: AssociationToOne {
    public typealias OriginRowDecoder = Origin
    public typealias RowDecoder = Destination
}
