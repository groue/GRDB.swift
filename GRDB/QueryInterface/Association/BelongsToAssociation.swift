public struct BelongsToAssociation<Origin, Destination>: Association {
    fileprivate let joinConditionRequest: ForeignKeyJoinConditionRequest
    
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination

    public var key: String
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>

    public func forKey(_ key: String) -> BelongsToAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try joinConditionRequest.fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> BelongsToAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

extension BelongsToAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension TableRecord {
    /// TODO
    public static func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: databaseTableName,
            destinationTable: Destination.databaseTableName,
            foreignKey: foreignKey)
        
        let joinConditionRequest = ForeignKeyJoinConditionRequest(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: true)

        return BelongsToAssociation(
            joinConditionRequest: joinConditionRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(Destination.all()))
    }
}
