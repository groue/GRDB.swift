public struct HasManyThroughAssociation<Origin, Destination>: Association {
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

// Allow HasManyThroughAssociation(...).filter(key: ...)
extension HasManyThroughAssociation: TableRequest where Destination: TableRecord { }

extension TableRecord {
    public static func hasMany<Pivot, Target>(
        _ target: Target,
        through pivot: Pivot)
        -> HasManyThroughAssociation<Self, Target.RowDecoder>
        where Pivot: Association,
        Target: Association,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        return HasManyThroughAssociation(sqlAssociation: target.sqlAssociation.appending(pivot.sqlAssociation))
    }
}
