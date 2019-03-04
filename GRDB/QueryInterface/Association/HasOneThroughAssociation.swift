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
