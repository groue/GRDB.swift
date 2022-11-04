/// The `JoinAssociation` joins common table expression to regular
/// tables or other common table expressions.
public struct JoinAssociation<Origin, Destination> {
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

extension JoinAssociation: AssociationToOne {
    public typealias OriginRowDecoder = Origin
    public typealias RowDecoder = Destination
}
