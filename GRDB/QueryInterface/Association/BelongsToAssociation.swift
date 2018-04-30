public struct BelongsToAssociation<Left, Right> : Association, TableRequest where
    Left: TableRecord,
    Right: TableRecord
{
    public typealias LeftAssociated = Left
    public typealias RightAssociated = Right
    
    public var key: String
    
    /// :nodoc:
    public var databaseTableName: String { return RightAssociated.databaseTableName }
    
    /// :nodoc:
    public var request: AssociationRequest<Right>
    
    let foreignKeyRequest: ForeignKeyRequest

    public func forKey(_ key: String) -> BelongsToAssociation<Left, Right> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try ForeignKeyJoinConditionRequest(foreignKeyRequest: foreignKeyRequest, originIsLeft: true).fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Right>) -> AssociationRequest<Right>) -> BelongsToAssociation<Left, Right> {
        var association = self
        association.request = transform(request)
        return association
    }
}

extension TableRecord {
    // TODO: Make it public if and only if we really want to build an association from any request
    static func belongsTo<Right>(
        _ rightRequest: QueryInterfaceRequest<Right>,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Right>
        where Right: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: databaseTableName,
            destinationTable: Right.databaseTableName,
            foreignKey: foreignKey)
        
        return BelongsToAssociation(
            key: key ?? Right.databaseTableName,
            request: AssociationRequest(rightRequest),
            foreignKeyRequest: foreignKeyRequest)
    }
    
    /// TODO
    public static func belongsTo<Right>(
        _ right: Right.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> BelongsToAssociation<Self, Right>
        where Right: TableRecord
    {
        return belongsTo(Right.all(), key: key, using: foreignKey)
    }
}
