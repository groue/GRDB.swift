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
    
    /// Creates a `JoinAssociation` whose key is the table name of the relation.
    init(
        to relation: SQLRelation,
        condition: SQLAssociationCondition)
    {
        guard let tableName = relation.source.tableName else {
            // Table name is only nil for SQLSource.subquery, which is only
            // involved in the "trivial count query" (see SQLQuery.trivialCountQuery):
            //
            //      // SELECT COUNT(*) FROM (SELECT * FROM player LIMIT 10)
            //      let request = Player.limit(10)
            //      let count = try request.fetchCount(db)
            //
            // This fatal error can not currently happen.
            fatalError("Association is not based on a database table")
        }
        
        _sqlAssociation = _SQLAssociation(
            key: .inflected(tableName),
            condition: condition,
            relation: relation,
            cardinality: .toOne)
    }
}
