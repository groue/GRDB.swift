public struct BelongsToAssociation<Origin, Destination> : Association, TableRequest where
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

    public func forKey(_ key: String) -> BelongsToAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try ForeignKeyJoinConditionRequest(foreignKeyRequest: foreignKeyRequest, originIsLeft: true).fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> BelongsToAssociation<Origin, Destination> {
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
    static func belongsTo<Destination>(
        _ request: QueryInterfaceRequest<Destination>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: databaseTableName,
            destinationTable: Destination.databaseTableName,
            foreignKey: foreignKey)
        
        return BelongsToAssociation(
            foreignKeyRequest: foreignKeyRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(request))
    }
    
    /// TODO
    public static func belongsTo<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Destination>
        where Destination: TableRecord
    {
        return belongsTo(Destination.all(), key: key, using: foreignKey)
    }
}
