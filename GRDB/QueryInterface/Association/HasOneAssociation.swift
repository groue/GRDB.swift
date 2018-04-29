public struct HasOneAssociation<Left, Right> : Association, TableRequest where
    Left: TableRecord,
    Right: TableRecord
{
    public typealias LeftAssociated = Left
    public typealias RightAssociated = Right
    
    public var key: String
    
    // :nodoc:
    public var databaseTableName: String { return RightAssociated.databaseTableName }
    
    // :nodoc:
    public let request: AssociationRequest<Right>
    
    let foreignKeyRequest: ForeignKeyRequest
    
    public func forKey(_ key: String) -> HasOneAssociation<Left, Right> {
        return HasOneAssociation(
            key: key,
            request: request,
            foreignKeyRequest: foreignKeyRequest)
    }
    
    // :nodoc:
    public func associationMapping(_ db: Database) throws -> AssociationMapping {
        return try AssociationMappingRequest
            .foreignKey(request: foreignKeyRequest, originIsLeft: false)
            .fetch(db)
    }
    
    // :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Right>) -> AssociationRequest<Right>) -> HasOneAssociation<Left, Right> {
        return HasOneAssociation(
            key: key,
            request: transform(request),
            foreignKeyRequest: foreignKeyRequest)
    }
}

extension TableRecord {
    // TODO: Make it public if and only if we really want to build an association from any request
    static func hasOne<Right>(
        _ rightRequest: QueryInterfaceRequest<Right>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasOneAssociation<Self, Right>
        where Right: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: Right.databaseTableName,
            destinationTable: databaseTableName,
            foreignKey: foreignKey)
        
        return HasOneAssociation(
            key: key ?? defaultAssociationKey(for: Right.self),
            request: AssociationRequest(rightRequest),
            foreignKeyRequest: foreignKeyRequest)
    }
    
    /// TODO
    public static func hasOne<Right>(
        _ right: Right.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasOneAssociation<Self, Right>
        where Right: TableRecord
    {
        return hasOne(Right.all(), key: key, using: foreignKey)
    }
}
