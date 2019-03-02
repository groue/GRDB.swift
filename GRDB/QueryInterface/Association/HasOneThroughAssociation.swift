public struct HasOneThroughAssociation<Origin, Destination>: ToOneAssociation {
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

extension TableRecord {
    public static func hasOne<Pivot, Target>(
        _ target: Target,
        through pivot: Pivot)
        -> HasOneThroughAssociation<Self, Target.RowDecoder>
        where Pivot: ToOneAssociation,
        Target: ToOneAssociation,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        return HasOneThroughAssociation(sqlAssociation: target.sqlAssociation.appending(pivot.sqlAssociation))
    }
}
