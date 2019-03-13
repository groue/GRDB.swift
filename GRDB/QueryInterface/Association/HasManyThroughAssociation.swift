/// The **HasManyThrough** association is often used to set up a many-to-many
/// connection with another record. This association indicates that the
/// declaring record can be matched with zero or more instances of another
/// record by proceeding through a third record.
///
/// For example, consider the practice of passport delivery. One coutry
/// "has many" citizens "through" its passports:
///
///     struct Country: TableRecord {
///         static let passports = hasMany(Passport.self)
///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
///         ...
///     }
///
///     struct Passport: TableRecord {
///         static let citizen = belongsTo(Citizen.self)
///         ...
///     }
///
///     struct Citizen: TableRecord { ... }
///
/// The **HasManyThrough** association is also useful for setting up
/// "shortcuts" through nested HasMany associations. For example, if a document
/// has many sections, and a section has many paragraphs, you may sometimes want
/// to get a simple collection of all paragraphs in the document. You could set
/// that up this way:
///
///     struct Document: TableRecord {
///         static let sections = hasMany(Section.self)
///         static let paragraphs = hasMany(Paragraph.self, through: sections, using: Section.paragraphs)
///     }
///
///     struct Section: TableRecord {
///         static let paragraphs = hasMany(Paragraph.self)
///     }
///
///     struct Paragraph: TableRecord {
///     }
///
/// As in the examples above, **HasManyThrough** association is always built from
/// two other associations: the `through:` and `using:` arguments. Those
/// associations can be any other association (BelongsTo, HasMany,
/// HasManyThrough, etc).
public struct HasManyThroughAssociation<Origin, Destination>: AssociationToMany {
    /// :nodoc:
    public typealias OriginRowDecoder = Origin
    
    /// :nodoc:
    public typealias RowDecoder = Destination
    
    /// :nodoc:
    public var sqlAssociation: SQLAssociation
    
    /// :nodoc:
    public init(sqlAssociation: SQLAssociation) {
        self.sqlAssociation = sqlAssociation
    }
}

// Allow HasManyThroughAssociation(...).filter(key: ...)
extension HasManyThroughAssociation: TableRequest where Destination: TableRecord { }

extension TableRecord {
    /// Creates a "Has Many Through" association between Self and the
    /// destination type.
    ///
    ///     struct Country: TableRecord {
    ///         static let passports = hasMany(Passport.self)
    ///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
    ///     }
    ///
    ///     struct Passport: TableRecord {
    ///         static let citizen = belongsTo(Citizen.self)
    ///     }
    ///
    ///     struct Citizen: TableRecord { }
    ///
    /// The association will let you define requests that load both the source
    /// and the destination type:
    ///
    ///     // A request for all (country, citizen) pairs:
    ///     let request = Country.including(required: Coutry.citizens)
    ///
    /// To consume those requests, define a type that adopts both the
    /// FetchableRecord and Decodable protocols:
    ///
    ///     struct Citizenship: FetchableRecord, Decodable {
    ///         var country: Country
    ///         var citizen: Citizen
    ///     }
    ///
    ///     let citizenships = try dbQueue.read { db in
    ///         return try Citizenship.fetchAll(db, request)
    ///     }
    ///     for citizenship in citizenships {
    ///         print("\(citizenship.citizen.name) is a citizen of \(citizenship.country.name)")
    ///     }
    ///
    /// It is recommended that you define, alongside the static association, a
    /// property with the same name:
    ///
    ///     struct Country: TableRecord, EncodableRecord {
    ///         static let passports = hasMany(Passport.self)
    ///         static let citizens = hasMany(Citizen.self, through: passports, using: Passport.citizen)
    ///         var citizens: QueryInterfaceRequest<Citizen> {
    ///             return request(for: Country.citizens)
    ///         }
    ///     }
    ///
    /// This property will let you navigate from the source type to the
    /// destination type:
    ///
    ///     try dbQueue.read { db in
    ///         let country: Country = ...
    ///         let citizens = try country.citizens.fetchAll(db) // [Country]
    ///     }
    ///
    /// - parameters:
    ///     - destination: The record type at the other side of the association.
    ///     - through: An association from Self to the intermediate type.
    ///     - using: An association from the intermediate type to the
    ///       destination type.
    public static func hasMany<Pivot, Target>(
        _ destination: Target.RowDecoder.Type,
        through pivot: Pivot,
        using target: Target)
        -> HasManyThroughAssociation<Self, Target.RowDecoder>
        where Pivot: Association,
        Target: Association,
        Pivot.OriginRowDecoder == Self,
        Pivot.RowDecoder == Target.OriginRowDecoder
    {
        return HasManyThroughAssociation(sqlAssociation: target.sqlAssociation.appending(pivot.sqlAssociation))
    }
}
