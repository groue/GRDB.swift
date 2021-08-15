/// The Join association is used to join common table expression to regular
/// tables or other common table expressions.
public struct JoinAssociation<Origin, Destination>: AssociationToOne {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _sqlAssociation: _SQLAssociation
    
    /// Creates a `JoinAssociation` whose key is the table name of the relation.
    init(
        to relation: SQLRelation,
        condition: SQLAssociationCondition)
    {
        _sqlAssociation = _SQLAssociation(
            key: .inflected(relation.source.tableName),
            condition: condition,
            relation: relation,
            cardinality: .toOne)
    }
}
