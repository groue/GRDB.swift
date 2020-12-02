/// The Join association is used to join common table expression to regular
/// tables or other common table expressions.
public struct JoinAssociation<Origin, Destination>: AssociationToOne {
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
    
    init(
        key: SQLAssociationKey,
        condition: SQLAssociationCondition,
        relation: SQLRelation)
    {
        _sqlAssociation = _SQLAssociation(
            key: key,
            condition: condition,
            relation: relation,
            cardinality: .toOne)
    }
}
