public struct HasManyAssociation<Origin, Destination> : Association, TableRequest where
    Origin: TableRecord,
    Destination: TableRecord
{
    fileprivate let foreignKeyRequest: ForeignKeyRequest
    
    // Association conformance

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
        return try ForeignKeyJoinConditionRequest(foreignKeyRequest: foreignKeyRequest, originIsLeft: false).fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> HasManyAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
    
    // TableRequest conformance
    
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension TableRecord {
    // TODO: Make it public if and only if we really want to build an association from any request
    static func hasMany<Destination>(
        _ request: QueryInterfaceRequest<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasManyAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: Destination.databaseTableName,
            destinationTable: databaseTableName,
            foreignKey: foreignKey)
        
        return HasManyAssociation(
            foreignKeyRequest: foreignKeyRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(request))
    }
    
    /// TODO
    public static func hasMany<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasManyAssociation<Self, Destination>
        where Destination: TableRecord
    {
        return hasMany(Destination.all(), key: key, using: foreignKey)
    }
}
