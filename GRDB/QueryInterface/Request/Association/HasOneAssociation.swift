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
///    See <https://sqlite.org/foreignkeys.html#fk_actions> for more information.
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
public struct HasOneAssociation<Origin, Destination>: AssociationToOne {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var _sqlAssociation: _SQLAssociation
    
    init(
        to destinationRelation: SQLRelation,
        key: String?,
        using foreignKey: ForeignKey?)
    {
        let destinationTable = destinationRelation.source.tableName
        
        let foreignKeyCondition = SQLForeignKeyCondition(
            destinationTable: destinationTable,
            foreignKey: foreignKey,
            originIsLeft: false)
        
        let associationKey: SQLAssociationKey
        if let key = key {
            associationKey = .fixedSingular(key)
        } else {
            associationKey = .inflected(destinationTable)
        }
        
        _sqlAssociation = _SQLAssociation(
            key: associationKey,
            condition: .foreignKey(foreignKeyCondition),
            relation: destinationRelation,
            cardinality: .toOne)
    }
}
