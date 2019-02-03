/// The HasOne association indicates a one-to-one connection between two
/// record types, such as each instance of the declaring record "has one"
/// instances of the other record.
///
/// For example, if your application has one database table for countries, and
/// another for their demographic profiles, you'd declare the association
/// this way:
///
///     struct Demographics: TableRecord { ... }
///     struct Country: TableRecord {
///         static let demographics = hasOne(Demographics.self)
///         ...
///     }
///
/// HasOne associations should be supported by an SQLite foreign key.
///
/// Foreign keys are the recommended way to declare relationships between
/// database tables because not only will SQLite guarantee the integrity of your
/// data, but GRDB will be able to use those foreign keys to automatically
/// configure your association.
///
/// You define the foreign key when you create database tables. For example:
///
///     try db.create(table: "country") { t in
///         t.column("code", .text).primaryKey()           // (1)
///         t.column("name", .text)
///     }
///     try db.create(table: "demographics") { t in
///         t.autoIncrementedPrimaryKey("id")
///         t.column("countryCode", .text)                 // (2)
///             .notNull()                                 // (3)
///             .unique()                                  // (4)
///             .references("country", onDelete: .cascade) // (5)
///         t.column("population", .integer)
///         t.column("density", .double)
///     }
///
/// 1. The country table has a primary key.
/// 2. The demographics.countryCode column is used to link a demographic
///    profile to the country it belongs to.
/// 3. Make the demographics.countryCode column not null if you want SQLite to
///    guarantee that all profiles are linked to a country.
/// 4. Create a unique index on the demographics.countryCode column in order to
///    guarantee the unicity of any country's profile.
/// 5. Create a foreign key from demographics.countryCode column to
///    country.code, so that SQLite guarantees that no profile refers to a
///    missing country. The `onDelete: .cascade` option has SQLite automatically
///    delete a profile when its country is deleted.
///    See https://sqlite.org/foreignkeys.html#fk_actions for more information.
///
/// The example above uses a string primary for the country table. But generally
/// speaking, all primary keys are supported.
///
/// If the database schema does not follow this convention, and does not define
/// foreign keys between tables, you can still use HasOne associations. But
/// your help is needed to define the missing foreign key:
///
///     struct Country: FetchableRecord, TableRecord {
///         static let demographics = hasOne(Demographics.self, using: ForeignKey(...))
///     }
///
/// See ForeignKey for more information.
public struct HasOneAssociation<Origin, Destination>: Association {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _impl: JoinAssociationImpl
    
    /// :nodoc:
    public init(_impl: JoinAssociationImpl) {
        self._impl = _impl
    }
}

// Allow HasOneAssociation(...).filter(key: ...)
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
        
        let joinCondition = JoinCondition(
            foreignKeyRequest: foreignKeyRequest,
            originIsLeft: false)
        
        return HasOneAssociation(_impl: JoinAssociationImpl(
            key: key ?? Destination.databaseTableName,
            joinCondition: joinCondition,
            relation: Destination.all().relation))
    }
}
