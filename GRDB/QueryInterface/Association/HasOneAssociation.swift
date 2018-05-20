public struct HasOneAssociation<Origin, Destination> : Association {
    fileprivate let joinConditionRequest: ForeignKeyJoinConditionRequest

    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    public var key: String
    
    /// :nodoc:
    public var request: AssociationRequest<Destination>
    
    public func forKey(_ key: String) -> HasOneAssociation<Origin, Destination> {
        var association = self
        association.key = key
        return association
    }
    
    /// :nodoc:
    public func joinCondition(_ db: Database) throws -> JoinCondition {
        return try joinConditionRequest.fetch(db)
    }
    
    /// :nodoc:
    public func mapRequest(_ transform: (AssociationRequest<Destination>) -> AssociationRequest<Destination>) -> HasOneAssociation<Origin, Destination> {
        var association = self
        association.request = transform(request)
        return association
    }
}

extension HasOneAssociation: TableRequest where Destination: TableRecord {
    /// :nodoc:
    public var databaseTableName: String { return Destination.databaseTableName }
}

extension TableRecord {
    /// Creates a "Has one" association between Self and the
    /// destination type.
    ///
    ///     struct Demographics: TableRecord { ... }
    ///     struct Country: TableRecord {
    ///         static let demographics = hasOne(Demographics.self)
    ///     }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all countries with their demographic profile:
    ///     let request = Country.including(optional: Country.demographics)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct CountryInfo: FetchableRecord, Decodable {
    ///         var country: Country
    ///         var demographics: Demographics?
    ///     }
    ///
    ///     let countryInfos = try dbQueue.read { db in
    ///         return try CountryInfo.fetchAll(db, request)
    ///     }
    ///     for countryInfo in countryInfos {
    ///         print("\(countryInfo.country.name) has \(countryInfo.demographics.population) citizens")
    ///     }
    ///
    /// It is recommended that you define, alongside the association, a property
    /// with the same name:
    ///
    ///     struct Country: TableRecord {
    ///         static let demographics = hasOne(Demographics.self)
    ///         var demographics: QueryInterfaceRequest<Demographics> {
    ///             return request(for: Country.demographics)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let country: Country = ...
    ///         let demographics = try country.demographics.fetchOne(db) // Demographics?
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - key: An eventual decoding key for the association. By default, it
    ///       is `destination.databaseTableName`.
    ///     - foreignKey: An eventual foreign key. You need to provide an
    ///       explicit foreign key when GRDB can't infer one from the database
    ///       schema. This happens when the schema does not define any foreign
    ///       key from the destination table, or when the schema defines several
    ///       foreign keys from the destination table.
    public static func hasOne<Destination>(
        _ destination: Destination.Type,
        key: String? = nil,
        using foreignKey: ForeignKey? = nil)
        -> HasOneAssociation<Self, Destination>
        where Destination: TableRecord
    {
        let foreignKeyRequest = ForeignKeyRequest(
            originTable: Destination.databaseTableName,
            destinationTable: databaseTableName,
            foreignKey: foreignKey)
        
        let joinConditionRequest = ForeignKeyJoinConditionRequest(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        return HasOneAssociation(
            joinConditionRequest: joinConditionRequest,
            key: key ?? Destination.databaseTableName,
            request: AssociationRequest(Destination.all()))
    }
}
