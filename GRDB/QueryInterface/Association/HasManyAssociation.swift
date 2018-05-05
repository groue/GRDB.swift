public struct HasManyAssociation<Origin, Destination>: Association {
    fileprivate let joinConditionRequest: ForeignKeyJoinConditionRequest

    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination

    public var key: String
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>
    
    public func forKey(_ key: String) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try joinConditionRequest.fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

extension HasManyAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension TableRecord {
    /// TODO
    public static func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasManyAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: Destination.databaseTableName,
            destinationTable: databaseTableName,
            foreignKey: foreignKey)
        
        let joinConditionRequest = ForeignKeyJoinConditionRequest(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        return HasManyAssociation(
            joinConditionRequest: joinConditionRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(Destination.all()))
    }
}
